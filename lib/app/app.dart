import 'package:flutter/material.dart';

import '../core/notifications/workout_reminder_service.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_page.dart';
import '../features/workout/workout_plan_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WorkoutReminderService.instance.setNotificationTapHandler(
      _onNotificationTap,
    );
  }

  void _onNotificationTap(String? payload) {
    if (payload != WorkoutReminderService.workoutPlanPayload) return;
    rootNavigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const WorkoutPlanPage(),
      ),
    );
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
