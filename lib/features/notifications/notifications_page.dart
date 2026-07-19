import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/notifications/notification_inbox_repository.dart';
import '../../core/notifications/workout_reminder_service.dart';
import '../../core/theme/app_colors.dart';
import '../planner/user_preferences_repository.dart';
import '../workout/workout_plan_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  final UserPreferencesRepository _prefsRepository =
      UserPreferencesRepository();
  final WorkoutReminderService _reminderService =
      WorkoutReminderService.instance;
  final NotificationInboxRepository _inbox =
      NotificationInboxRepository.instance;

  PermissionStatus? _status;
  bool _loadingPermission = false;
  bool _loadingDiagnostics = false;
  ReminderDiagnostics? _diagnostics;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncInboxAndMarkRead());
    _refreshTopState();
  }

  Future<void> _syncInboxAndMarkRead() async {
    await _reminderService.syncDeliveredNotifications();
    await _reminderService.syncMissedReminders(_prefsRepository);
    await _inbox.markAllRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTopState();
      _reminderService.syncMissedReminders(_prefsRepository).catchError((_) {});
    }
  }

  Future<void> _refreshTopState() async {
    if (_loadingPermission || _loadingDiagnostics) return;
    setState(() {
      _loadingPermission = true;
      _loadingDiagnostics = true;
    });
    try {
      final PermissionStatus status = await Permission.notification.status;
      final ReminderDiagnostics diagnostics = await _reminderService
          .getDiagnostics();
      if (!mounted) return;
      setState(() {
        _status = status;
        _diagnostics = diagnostics;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPermission = false;
          _loadingDiagnostics = false;
        });
      }
    }
  }

  bool get _permissionGranted {
    final PermissionStatus? s = _status;
    return s == PermissionStatus.granted || s == PermissionStatus.limited;
  }

  Future<void> _requestPermission() async {
    setState(() => _loadingPermission = true);
    try {
      await _reminderService.ensureReminderPermissions();
    } finally {
      await _refreshTopState();
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    await _refreshTopState();
  }

  void _openWorkoutPlan() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const WorkoutPlanPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        titleSpacing: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refreshTopState,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              StreamBuilder<WorkoutReminderPrefs>(
                stream: _prefsRepository.watchWorkoutReminder(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<WorkoutReminderPrefs> snapshot,
                    ) {
                      final WorkoutReminderPrefs prefs =
                          snapshot.data ?? const WorkoutReminderPrefs();
                      return _PermissionCard(
                        loading: _loadingPermission || _loadingDiagnostics,
                        reminderPrefs: prefs,
                        permissionGranted: _permissionGranted,
                        diagnostics: _diagnostics,
                        onRequestPermission: _requestPermission,
                        onOpenSettings: _openSettings,
                        onOpenWorkoutPlan: _openWorkoutPlan,
                        onRefresh: _refreshTopState,
                      );
                    },
              ),
              const SizedBox(height: 20),
              const Text(
                'History',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<InboxNotification>>(
                stream: _inbox.watchAll(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<InboxNotification>> snapshot,
                    ) {
                      final List<InboxNotification> items =
                          snapshot.data ?? <InboxNotification>[];
                      if (items.isEmpty) {
                        return const _EmptyInboxState();
                      }
                      return Column(
                        children: items
                            .map(
                              (InboxNotification item) =>
                                  _InboxNotificationRow(notification: item),
                            )
                            .toList(),
                      );
                    },
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.loading,
    required this.reminderPrefs,
    required this.permissionGranted,
    required this.diagnostics,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onOpenWorkoutPlan,
    required this.onRefresh,
  });

  final bool loading;
  final WorkoutReminderPrefs reminderPrefs;
  final bool permissionGranted;
  final ReminderDiagnostics? diagnostics;
  final Future<void> Function() onRequestPermission;
  final Future<void> Function() onOpenSettings;
  final VoidCallback onOpenWorkoutPlan;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final String reminderText = reminderPrefs.enabled && reminderPrefs.hasTime
        ? reminderPrefs.formatTime()
        : (reminderPrefs.enabled ? 'Enabled (time not set)' : 'Off');
    final String permissionText = permissionGranted ? 'Enabled' : 'Disabled';
    final String channelText = diagnostics?.channelImportance ?? 'unknown';
    final String exactAlarmsText = diagnostics?.canScheduleExactAlarms == null
        ? 'n/a'
        : (diagnostics!.canScheduleExactAlarms! ? 'granted' : 'not granted');
    final String queueText = diagnostics == null
        ? 'checking...'
        : '${diagnostics!.pendingReminderCount} pending';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Turn on notifications',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(
                    Icons.refresh,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Permission: $permissionText | Reminder: $reminderText',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Channel importance: $channelText | Queue: $queueText',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Exact alarms: $exactAlarmsText',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (diagnostics?.nextReminderAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Next scheduled: ${diagnostics!.nextReminderAt}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: onRequestPermission,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Enable notifications'),
              ),
              OutlinedButton(
                onPressed: onOpenSettings,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.secondary),
                ),
                child: const Text('App settings'),
              ),
              TextButton(
                onPressed: onOpenWorkoutPlan,
                child: const Text('Go to Workout Plan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyInboxState extends StatelessWidget {
  const _EmptyInboxState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          const Text(
            'No notifications yet',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Workout reminders and taps will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxNotificationRow extends StatelessWidget {
  const _InboxNotificationRow({required this.notification});

  final InboxNotification notification;

  @override
  Widget build(BuildContext context) {
    final Color titleColor = notification.read
        ? AppColors.textSecondary
        : AppColors.text;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Icon(
              notification.type == 'workout_test'
                  ? Icons.science_outlined
                  : Icons.fitness_center,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: notification.read
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAgo(notification.createdAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!notification.read)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  static String _formatAgo(DateTime createdAt) {
    final Duration diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }
}
