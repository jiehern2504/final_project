import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/planner/user_preferences_repository.dart';

const int _kReminderNotificationId = 1001;
const int _kTestNotificationId = 2001;
const String _kWorkoutChannelId = 'workout_reminders';

const int _kMaxInboxItems = 50;
const String _kItemsKey = 'notification_inbox_items';
const String _kLastSyncKey = 'notification_inbox_last_sync';

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    required this.type,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String type;

  InboxNotification copyWith({bool? read}) {
    return InboxNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
      type: type,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
    'type': type,
  };

  static InboxNotification fromJson(Map<String, dynamic> json) {
    return InboxNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      read: json['read'] as bool? ?? false,
      type: json['type'] as String? ?? 'general',
    );
  }
}

class NotificationInboxRepository {
  NotificationInboxRepository._();

  static final NotificationInboxRepository instance =
      NotificationInboxRepository._();

  final StreamController<int> _unreadController =
      StreamController<int>.broadcast();
  final StreamController<List<InboxNotification>> _itemsController =
      StreamController<List<InboxNotification>>.broadcast();

  final Set<int> _seenActiveNotificationIds = <int>{};

  Stream<int> watchUnreadCount() {
    return Stream<int>.multi((MultiStreamController<int> controller) async {
      final StreamSubscription<int> sub = _unreadController.stream.listen(
        controller.add,
      );
      controller.onCancel = sub.cancel;
      final List<InboxNotification> items = await _loadItems();
      controller.add(_unreadCount(items));
    });
  }

  Stream<List<InboxNotification>> watchAll() {
    return Stream<List<InboxNotification>>.multi((
      MultiStreamController<List<InboxNotification>> controller,
    ) async {
      final StreamSubscription<List<InboxNotification>> sub = _itemsController
          .stream
          .listen(controller.add);
      controller.onCancel = sub.cancel;
      final List<InboxNotification> items = await _loadItems();
      controller.add(List<InboxNotification>.unmodifiable(items));
    });
  }

  int _unreadCount(List<InboxNotification> items) =>
      items.where((InboxNotification n) => !n.read).length;

  Future<List<InboxNotification>> _loadItems() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_kItemsKey);
    if (raw == null || raw.isEmpty) return <InboxNotification>[];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic e) =>
                InboxNotification.fromJson(e as Map<String, dynamic>),
          )
          .toList()
        ..sort(
          (InboxNotification a, InboxNotification b) =>
              b.createdAt.compareTo(a.createdAt),
        );
    } catch (_) {
      return <InboxNotification>[];
    }
  }

  Future<void> _saveItems(List<InboxNotification> items) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<InboxNotification> capped = items.length > _kMaxInboxItems
        ? items.sublist(0, _kMaxInboxItems)
        : items;
    await prefs.setString(
      _kItemsKey,
      jsonEncode(capped.map((InboxNotification n) => n.toJson()).toList()),
    );
    _unreadController.add(_unreadCount(capped));
    _itemsController.add(List<InboxNotification>.unmodifiable(capped));
  }

  Future<void> addWorkoutReminder({required DateTime firedAt}) async {
    final String id = 'workout_${_formatDate(firedAt)}';
    await _addIfNew(
      InboxNotification(
        id: id,
        title: 'Time for your workout!',
        body: 'Open the app to see today\'s plan.',
        createdAt: firedAt,
        read: false,
        type: 'workout_reminder',
      ),
    );
  }

  Future<void> syncDeliveredFromActiveNotifications(
    List<ActiveNotification> active,
  ) async {
    final List<ActiveNotification> ours = active
        .where(_isOurNotification)
        .toList();
    final Set<int> currentIds = ours
        .map((ActiveNotification n) => n.id)
        .whereType<int>()
        .toSet();

    _seenActiveNotificationIds.retainAll(currentIds);

    for (final ActiveNotification notification in ours) {
      final int? notificationId = notification.id;
      if (notificationId == null) continue;
      if (_seenActiveNotificationIds.contains(notificationId)) continue;

      _seenActiveNotificationIds.add(notificationId);

      if (notificationId == _kReminderNotificationId) {
        await addWorkoutReminder(firedAt: DateTime.now());
        debugPrint(
          'NotificationInbox: synced delivery id=$notificationId (daily)',
        );
      } else if (notificationId == _kTestNotificationId) {
        final String inboxId = 'test_${DateTime.now().millisecondsSinceEpoch}';
        await _addIfNew(
          InboxNotification(
            id: inboxId,
            title: notification.title ?? 'Workout reminder test',
            body:
                notification.body ??
                'This is a diagnostic notification trigger.',
            createdAt: DateTime.now(),
            read: false,
            type: 'workout_test',
          ),
        );
        debugPrint(
          'NotificationInbox: synced delivery id=$notificationId (test)',
        );
      }
    }
  }

  bool _isOurNotification(ActiveNotification notification) {
    final int? id = notification.id;
    if (id == _kReminderNotificationId || id == _kTestNotificationId) {
      return true;
    }
    return notification.channelId == _kWorkoutChannelId;
  }

  Future<void> addFromTap({
    String? title,
    String? body,
    String? payload,
    int? notificationId,
  }) async {
    final String id = _idFromTap(
      payload: payload,
      notificationId: notificationId,
    );
    final List<InboxNotification> items = await _loadItems();
    if (items.any((InboxNotification n) => n.id == id)) return;

    final bool isTest = payload == 'workout_plan_test';
    await _addIfNew(
      InboxNotification(
        id: id,
        title:
            title ??
            (isTest ? 'Workout reminder test' : 'Time for your workout!'),
        body:
            body ??
            (isTest
                ? 'This is a diagnostic notification trigger.'
                : 'Open the app to see today\'s plan.'),
        createdAt: DateTime.now(),
        read: false,
        type: isTest ? 'workout_test' : 'workout_reminder',
      ),
    );
  }

  Future<void> _addIfNew(InboxNotification notification) async {
    final List<InboxNotification> items = await _loadItems();
    if (items.any((InboxNotification n) => n.id == notification.id)) return;
    final List<InboxNotification> updated =
        <InboxNotification>[notification, ...items]..sort(
          (InboxNotification a, InboxNotification b) =>
              b.createdAt.compareTo(a.createdAt),
        );
    await _saveItems(updated);
  }

  Future<void> markAllRead() async {
    final List<InboxNotification> items = await _loadItems();
    if (items.every((InboxNotification n) => n.read)) return;
    await _saveItems(
      items.map((InboxNotification n) => n.copyWith(read: true)).toList(),
    );
  }

  Future<void> syncMissedReminders({
    required WorkoutReminderPrefs prefs,
  }) async {
    if (!prefs.enabled || !prefs.hasTime) {
      await _setLastSync(DateTime.now());
      return;
    }

    final DateTime now = DateTime.now();
    final SharedPreferences shared = await SharedPreferences.getInstance();
    final String? lastSyncRaw = shared.getString(_kLastSyncKey);
    final DateTime? lastSync = lastSyncRaw != null
        ? DateTime.tryParse(lastSyncRaw)
        : null;

    final DateTime startDay = lastSync != null
        ? DateTime(lastSync.year, lastSync.month, lastSync.day)
        : DateTime(now.year, now.month, now.day);

    DateTime day = startDay;
    final DateTime endDay = DateTime(now.year, now.month, now.day);

    while (!day.isAfter(endDay)) {
      final DateTime fireTime = DateTime(
        day.year,
        day.month,
        day.day,
        prefs.hour!,
        prefs.minute!,
      );
      if (!fireTime.isAfter(now)) {
        await addWorkoutReminder(firedAt: fireTime);
      }
      day = day.add(const Duration(days: 1));
    }

    await _setLastSync(now);
  }

  Future<void> _setLastSync(DateTime when) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastSyncKey, when.toIso8601String());
  }

  static String _formatDate(DateTime dt) {
    final String y = dt.year.toString().padLeft(4, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _idFromTap({String? payload, int? notificationId}) {
    if (notificationId == _kReminderNotificationId) {
      return 'workout_${_formatDate(DateTime.now())}';
    }
    if (notificationId == _kTestNotificationId) {
      return 'test_${DateTime.now().millisecondsSinceEpoch}';
    }
    return _idFromPayload(payload);
  }

  static String _idFromPayload(String? payload) {
    if (payload == null) {
      return 'tap_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (payload == 'workout_plan_test') {
      return 'test_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (payload.startsWith('workout_plan')) {
      final List<String> parts = payload.split('|');
      if (parts.length >= 2) {
        final DateTime? scheduled = DateTime.tryParse(parts.last);
        if (scheduled != null) {
          return 'workout_${_formatDate(scheduled)}';
        }
      }
      return 'workout_${_formatDate(DateTime.now())}';
    }
    return 'tap_$payload';
  }
}
