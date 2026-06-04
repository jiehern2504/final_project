import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/notifications/workout_reminder_service.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_page.dart';
import '../features/planner/user_preferences_repository.dart';
import '../features/workout/workout_plan_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final UserPreferencesRepository _preferencesRepository =
      UserPreferencesRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WorkoutReminderService.instance.setNotificationTapHandler(
      _onNotificationTap,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    WorkoutReminderService.instance
        .syncDeliveredNotifications()
        .catchError((_) {});
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    WorkoutReminderService.instance
        .rescheduleFromFirestore(_preferencesRepository)
        .catchError((_) {});
    WorkoutReminderService.instance
        .syncMissedReminders(_preferencesRepository)
        .catchError((_) {});
  }

  void _onNotificationTap(String? payload) {
    if (!_isWorkoutPlanPayload(payload)) return;
    rootNavigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const WorkoutPlanPage(),
      ),
    );
  }

  bool _isWorkoutPlanPayload(String? payload) {
    if (payload == null) return false;
    return payload == WorkoutReminderService.workoutPlanPayload ||
        payload.startsWith('${WorkoutReminderService.workoutPlanPayload}|') ||
        payload == 'workout_plan_test';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorKey: rootNavigatorKey,
      home: const AuthPage(),
    );
  }
}
