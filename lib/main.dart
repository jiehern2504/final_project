import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifications/workout_reminder_service.dart';
import 'features/planner/user_preferences_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Keep notification init in startup so reminders are ready before app routes.
  await WorkoutReminderService.instance.init();

  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      WorkoutReminderService.instance
          .rescheduleFromFirestore(UserPreferencesRepository())
          .catchError((_) {});
    } else {
      WorkoutReminderService.instance.cancelReminder().catchError((_) {});
    }
  });

  final UserPreferencesRepository preferencesRepository =
      UserPreferencesRepository();
  final User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await WorkoutReminderService.instance
        .rescheduleFromFirestore(preferencesRepository)
        .catchError((_) {});
    await WorkoutReminderService.instance
        .syncMissedReminders(preferencesRepository)
        .catchError((_) {});
  }

  await WorkoutReminderService.instance
      .syncDeliveredNotifications()
      .catchError((_) {});

  runApp(const MyApp());
}
