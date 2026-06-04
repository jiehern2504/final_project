import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_ai_app/core/notifications/notification_inbox_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationInboxRepository inbox;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    inbox = NotificationInboxRepository.instance;
  });

  Future<int> currentUnread() async {
    final List<InboxNotification> items = await inbox.watchAll().first;
    return items.where((InboxNotification n) => !n.read).length;
  }

  test('syncDeliveredFromActiveNotifications adds +1 for new test notification',
      () async {
    const ActiveNotification active = ActiveNotification(
      id: 2001,
      channelId: 'workout_reminders',
      title: 'Workout reminder test',
      body: 'Diagnostic body',
    );

    await inbox.syncDeliveredFromActiveNotifications(<ActiveNotification>[
      active,
    ]);
    expect(await currentUnread(), 1);

    await inbox.syncDeliveredFromActiveNotifications(<ActiveNotification>[
      active,
    ]);
    expect(await currentUnread(), 1);
  });

  test('markAllRead clears unread after delivery sync', () async {
    const ActiveNotification active = ActiveNotification(
      id: 2001,
      channelId: 'workout_reminders',
    );

    await inbox.syncDeliveredFromActiveNotifications(<ActiveNotification>[
      active,
    ]);
    await inbox.markAllRead();
    expect(await currentUnread(), 0);
  });
}
