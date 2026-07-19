import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/planner/user_preferences_repository.dart';
import 'notification_inbox_repository.dart';

const int _kReminderNotificationId = 1001;
const int _kTestNotificationId = 2001;
const AndroidScheduleMode _kAndroidScheduleMode =
    AndroidScheduleMode.exactAllowWhileIdle;
const String _kAndroidChannelId = 'workout_reminders';
const String _kAndroidChannelName = 'Workout reminders';
const String _kPayloadWorkoutPlan = 'workout_plan';
const String _kPayloadWorkoutPlanTest = 'workout_plan_test';

typedef NotificationTapCallback = void Function(String? payload);

class ReminderDiagnostics {
  const ReminderDiagnostics({
    required this.permissionStatus,
    required this.areNotificationsEnabled,
    required this.channelImportance,
    required this.pendingReminderCount,
    required this.hasMainReminderPending,
    required this.nextReminderAt,
    this.canScheduleExactAlarms,
  });

  final PermissionStatus permissionStatus;
  final bool? areNotificationsEnabled;
  final String? channelImportance;
  final int pendingReminderCount;
  final bool hasMainReminderPending;
  final DateTime? nextReminderAt;
  final bool? canScheduleExactAlarms;
}

class WorkoutReminderService {
  WorkoutReminderService._();

  static final WorkoutReminderService instance = WorkoutReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  bool _initialized = false;
  Future<void>? _initFuture;
  NotificationTapCallback? _onTap;

  void setNotificationTapHandler(NotificationTapCallback handler) {
    _onTap = handler;
  }

  Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture!;

    _initFuture = _initInternal();
    try {
      await _initFuture;
    } finally {
      if (!_initialized) {
        _initFuture = null;
      }
    }
  }

  Future<void> _initInternal() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('WorkoutReminderService: timezone fallback UTC ($e)');
      tz.setLocalLocation(tz.UTC);
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    await _createAndroidChannel();
    await _handleLaunchFromNotification();

    _initialized = true;
    await logDiagnostics(reason: 'init');
  }

  Future<void> _handleLaunchFromNotification() async {
    final NotificationAppLaunchDetails? launchDetails = await _plugin
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp != true) return;
    final NotificationResponse? response = launchDetails!.notificationResponse;
    if (response == null) return;
    _handleNotificationResponse(response);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    unawaited(_recordTapInInbox(response));
    _onTap?.call(response.payload);
  }

  Future<void> _recordTapInInbox(NotificationResponse response) async {
    await NotificationInboxRepository.instance.addFromTap(
      payload: response.payload,
      notificationId: response.id,
    );
  }

  Future<void> syncDeliveredNotifications() async {
    if (!_initialized) await init();

    List<ActiveNotification> active = <ActiveNotification>[];
    if (defaultTargetPlatform == TargetPlatform.android) {
      active =
          await _android?.getActiveNotifications() ?? <ActiveNotification>[];
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      active = await ios?.getActiveNotifications() ?? <ActiveNotification>[];
    } else {
      active = await _plugin.getActiveNotifications();
    }

    await NotificationInboxRepository.instance
        .syncDeliveredFromActiveNotifications(active);
  }

  Future<bool> ensureNotificationPermission() async {
    if (!_initialized) await init();

    PermissionStatus status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) return true;

    status = await Permission.notification.request();
    if (status.isGranted || status.isLimited) return true;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (granted == true) return true;
    }

    return false;
  }

  Future<bool> canScheduleExactAlarms() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    if (!_initialized) await init();
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  Future<bool> ensureExactAlarmPermission() async {
    if (await canScheduleExactAlarms()) return true;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return await _android?.requestExactAlarmsPermission() ?? false;
  }

  Future<bool> ensureReminderPermissions() async {
    final bool notificationsGranted = await ensureNotificationPermission();
    if (!notificationsGranted) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return ensureExactAlarmPermission();
  }

  Future<void> _createAndroidChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _kAndroidChannelId,
      _kAndroidChannelName,
      description: 'Daily reminders to work out',
      importance: Importance.high,
    );
    await _android?.createNotificationChannel(channel);
  }

  Future<ReminderDiagnostics> getDiagnostics() async {
    if (!_initialized) await init();
    final PermissionStatus permissionStatus =
        await Permission.notification.status;
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    final PendingNotificationRequest? mainReminder = pending
        .cast<PendingNotificationRequest?>()
        .firstWhere(
          (PendingNotificationRequest? request) =>
              request?.id == _kReminderNotificationId,
          orElse: () => null,
        );
    final DateTime? nextReminderAt = mainReminder == null
        ? null
        : _safeParseIsoDate(mainReminder.payload);
    bool? notificationsEnabled;
    String? channelImportance;
    bool? canScheduleExactAlarms;
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android != null) {
      notificationsEnabled = await android.areNotificationsEnabled();
      canScheduleExactAlarms = await android.canScheduleExactNotifications();
      final List<AndroidNotificationChannel>? channels = await android
          .getNotificationChannels();
      final AndroidNotificationChannel? reminderChannel = channels
          ?.cast<AndroidNotificationChannel?>()
          .firstWhere(
            (AndroidNotificationChannel? channel) =>
                channel?.id == _kAndroidChannelId,
            orElse: () => null,
          );
      channelImportance = reminderChannel?.importance.name;
    }
    return ReminderDiagnostics(
      permissionStatus: permissionStatus,
      areNotificationsEnabled: notificationsEnabled,
      channelImportance: channelImportance,
      pendingReminderCount: pending.length,
      hasMainReminderPending: mainReminder != null,
      nextReminderAt: nextReminderAt,
      canScheduleExactAlarms: canScheduleExactAlarms,
    );
  }

  Future<void> logDiagnostics({String reason = 'manual'}) async {
    final ReminderDiagnostics d = await getDiagnostics();
    debugPrint(
      'WorkoutReminderService diagnostics'
      ' reason=$reason'
      ' permission=${d.permissionStatus}'
      ' notificationsEnabled=${d.areNotificationsEnabled}'
      ' canScheduleExactAlarms=${d.canScheduleExactAlarms}'
      ' channelImportance=${d.channelImportance}'
      ' pending=${d.pendingReminderCount}'
      ' hasMainReminderPending=${d.hasMainReminderPending}'
      ' nextReminderAt=${d.nextReminderAt?.toIso8601String()}',
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
    bool repeatDaily = true,
  }) async {
    if (!_initialized) await init();

    try {
      await _plugin.cancel(id);
    } catch (error) {
      throw Exception('Could not clear existing notification $id: $error');
    }

    final tz.TZDateTime scheduled = _nextInstanceOfTime(hour, minute);
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _kAndroidChannelId,
          _kAndroidChannelName,
          channelDescription: 'Daily reminders to work out',
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: _kAndroidScheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
        payload: payload,
      );
      debugPrint(
        'WorkoutReminderService: notification scheduled for $scheduled',
      );
    } catch (error) {
      throw Exception('Could not schedule notification $id: $error');
    }
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) await init();
    final PermissionStatus notificationStatus =
        await Permission.notification.status;
    if (!notificationStatus.isGranted && !notificationStatus.isLimited) {
      throw StateError(
        'Notification permission is required to schedule workout reminders.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        !await canScheduleExactAlarms()) {
      throw StateError(
        'Exact alarm permission is required to schedule workout reminders '
        'at the chosen time. Enable Alarms & reminders for this app.',
      );
    }

    final tz.TZDateTime scheduled = _nextInstanceOfTime(hour, minute);
    try {
      await scheduleNotification(
        id: _kReminderNotificationId,
        title: 'Time for your workout!',
        body: 'Open the app to see today\'s plan.',
        hour: hour,
        minute: minute,
        payload: _buildReminderPayload(scheduled),
        repeatDaily: true,
      );
      await logDiagnostics(reason: 'scheduleDailyReminder');
    } catch (error) {
      throw Exception('Could not schedule workout reminder: $error');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelReminder() async {
    if (!_initialized) await init();
    try {
      await _plugin.cancel(_kReminderNotificationId);
      await logDiagnostics(reason: 'cancelReminder');
    } catch (error) {
      throw Exception('Could not cancel workout reminder: $error');
    }
  }

  Future<void> triggerTestNotification({
    Duration delay = const Duration(minutes: 2),
  }) async {
    if (!_initialized) await init();
    final PermissionStatus notificationStatus =
        await Permission.notification.status;
    if (!notificationStatus.isGranted && !notificationStatus.isLimited) {
      throw StateError(
        'Notification permission is required to schedule workout reminders.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        !await canScheduleExactAlarms()) {
      throw StateError(
        'Exact alarm permission is required to schedule workout reminders '
        'at the chosen time. Enable Alarms & reminders for this app.',
      );
    }

    final DateTime target = DateTime.now().add(delay);
    try {
      await scheduleNotification(
        id: _kTestNotificationId,
        title: 'Workout reminder test',
        body: 'This is a diagnostic notification trigger.',
        hour: target.hour,
        minute: target.minute,
        payload: _kPayloadWorkoutPlanTest,
        repeatDaily: false,
      );
      await logDiagnostics(reason: 'triggerTestNotification');
    } catch (error) {
      throw Exception('Could not schedule test notification: $error');
    }
  }

  Future<void> applyPrefs(WorkoutReminderPrefs prefs) async {
    if (prefs.enabled && prefs.hasTime) {
      await scheduleDailyReminder(hour: prefs.hour!, minute: prefs.minute!);
    } else {
      await cancelReminder();
    }
  }

  Future<void> rescheduleFromFirestore(
    UserPreferencesRepository repository,
  ) async {
    if (!_initialized) await init();
    final WorkoutReminderPrefs prefs = await repository.fetchWorkoutReminder();
    await applyPrefs(prefs);
  }

  Future<void> syncMissedReminders(UserPreferencesRepository repository) async {
    if (!_initialized) await init();
    final WorkoutReminderPrefs prefs = await repository.fetchWorkoutReminder();
    await NotificationInboxRepository.instance.syncMissedReminders(
      prefs: prefs,
    );
  }

  static String get workoutPlanPayload => _kPayloadWorkoutPlan;

  String _buildReminderPayload(tz.TZDateTime scheduled) {
    return '$_kPayloadWorkoutPlan|${scheduled.toIso8601String()}';
  }

  DateTime? _safeParseIsoDate(String? payload) {
    if (payload == null) return null;
    final List<String> parts = payload.split('|');
    if (parts.length < 2) return null;
    return DateTime.tryParse(parts.last);
  }
}
