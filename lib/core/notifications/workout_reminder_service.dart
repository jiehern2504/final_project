import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/planner/user_preferences_repository.dart';

const int _kReminderNotificationId = 1001;
const String _kAndroidChannelId = 'workout_reminders';
const String _kAndroidChannelName = 'Workout reminders';
const String _kPayloadWorkoutPlan = 'workout_plan';

typedef NotificationTapCallback = void Function(String? payload);

class WorkoutReminderService {
  WorkoutReminderService._();

  static final WorkoutReminderService instance = WorkoutReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  NotificationTapCallback? _onTap;

  void setNotificationTapHandler(NotificationTapCallback handler) {
    _onTap = handler;
  }

  Future<void> init() async {
    if (_initialized) return;

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
    await _requestNotificationPermission();

    _initialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _onTap?.call(response.payload);
  }

  Future<void> _createAndroidChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _kAndroidChannelId,
      _kAndroidChannelName,
      description: 'Daily reminders to work out',
      importance: Importance.defaultImportance,
    );
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(channel);
  }

  Future<void> _requestNotificationPermission() async {
    final PermissionStatus status = await Permission.notification.request();
    if (!status.isGranted && defaultTargetPlatform == TargetPlatform.android) {
      debugPrint('WorkoutReminderService: notification permission not granted');
    }
    final IOSFlutterLocalNotificationsPlugin? ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) await init();
    final PermissionStatus notificationStatus =
        await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      throw StateError(
        'Notification permission is required to schedule workout reminders.',
      );
    }

    try {
      await _plugin.cancel(_kReminderNotificationId);
    } catch (error) {
      throw Exception('Could not clear existing reminder: $error');
    }

    final tz.TZDateTime scheduled = _nextInstanceOfTime(hour, minute);
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _kAndroidChannelId,
          _kAndroidChannelName,
          channelDescription: 'Daily reminders to work out',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        _kReminderNotificationId,
        'Time for your workout!',
        'Open the app to see today\'s plan.',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: _kPayloadWorkoutPlan,
      );
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
    } catch (error) {
      throw Exception('Could not cancel workout reminder: $error');
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

  static String get workoutPlanPayload => _kPayloadWorkoutPlan;
}
