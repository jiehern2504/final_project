import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../achievement/achievement_page.dart';
import '../planner/pages/ai_chat_page.dart';
import '../planner/models/workout_plan_models.dart';
import '../planner/repositories/workout_plan_repository.dart';
import '../pose/pose_exercise_picker_page.dart';
import '../profile/profile_page.dart';
import '../progress/progress_page.dart';
import '../tdee/tdee_bmi_page.dart';
import '../../core/notifications/notification_inbox_repository.dart';
import '../../core/notifications/workout_reminder_service.dart';
import '../../core/profile/age_updater.dart';
import '../notifications/notifications_page.dart';
import '../workout/workout_plan_page.dart';
import '../tutorial/muscle_tutorial_page.dart';
import '../recommended/recommended_video.dart';
import '../recommended/recommended_list_page.dart';
import '../summary/summary_card.dart';
import '../recommended/open_video.dart';
import '../recommended/video_thumbnail.dart';
import '../../core/theme/app_colors.dart';

part 'widgets/home_greeting.dart';
part 'widgets/home_shortcuts.dart';
part 'widgets/home_section_header.dart';
part 'widgets/home_recommendations.dart';
part 'widgets/home_progress_card.dart';
part 'widgets/home_bottom_bar.dart';

const Color _kPrimaryColor = AppColors.primary;
const Color _kSecondaryColor = AppColors.secondary;
const Color _kBackgroundColor = AppColors.background;
const Color _kCardColor = Colors.white;
const Color _kTextColor = AppColors.text;

Color _withOpacity(Color color, double opacity) {
  final int a = (opacity * 255).round().clamp(0, 255);
  return color.withAlpha(a);
}

void _openProgress(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const ProgressPage(),
    ),
  );
}

void _openAiChat(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const AiChatPage(),
    ),
  );
}

void _openWorkoutPlan(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const WorkoutPlanPage(),
    ),
  );
}

void _openTdee(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const TdeeBmiPage(),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final WorkoutPlanRepository _planRepository = WorkoutPlanRepository();
  Timer? _deliverySyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deliverySyncTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => WorkoutReminderService.instance
          .syncDeliveredNotifications()
          .catchError((_) {}),
    );
    WorkoutReminderService.instance
        .syncDeliveredNotifications()
        .catchError((_) {});
    // Bump the user's age if a year has passed since it was last set.
    AgeUpdater.maybeAdvance();
  }

  @override
  void dispose() {
    _deliverySyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WorkoutReminderService.instance
          .syncDeliveredNotifications()
          .catchError((_) {});
    }
  }

  String _firstName() {
    final User? user = FirebaseAuth.instance.currentUser;
    final String displayName = (user?.displayName ?? '').trim();
    if (displayName.isNotEmpty) {
      return displayName.split(RegExp(r'\s+')).first;
    }
    final String email = (user?.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GreetingSection(
                    firstName: _firstName(),
                    primaryColor: _kPrimaryColor,
                    secondaryColor: _kSecondaryColor,
                    textColor: _kTextColor,
                    onNotificationsTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              const NotificationsPage(),
                        ),
                      );
                    },
                    onAiChatTap: () => _openAiChat(context),
                  ),
                  const SizedBox(height: 22),
                  _ShortcutRow(
                    primaryColor: _kPrimaryColor,
                    secondaryColor: _kSecondaryColor,
                    cardColor: _kCardColor,
                    textColor: _kTextColor,
                    onWorkoutTap: () => _openWorkoutPlan(context),
                    onProgressTap: () => _openProgress(context),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Recommended Workouts',
                    actionLabel: 'See All',
                    textColor: _kTextColor,
                    accentColor: _kSecondaryColor,
                    onAction: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            const RecommendedListPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _RecommendationList(textColor: _kTextColor),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Your Progress',
                    textColor: _kTextColor,
                    actionLabel: 'See all',
                    accentColor: _kSecondaryColor,
                    onAction: () => _openProgress(context),
                  ),
                  const SizedBox(height: 14),
                  _ProgressCard(
                    primaryColor: _kPrimaryColor,
                    cardColor: _kCardColor,
                    textColor: _kTextColor,
                    onTapWithPlan: () => _openProgress(context),
                    onTapNoPlan: () => _openWorkoutPlan(context),
                    repository: _planRepository,
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Your Summary',
                    textColor: _kTextColor,
                    accentColor: _kSecondaryColor,
                  ),
                  const SizedBox(height: 14),
                  const SummaryCard(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _HomeBottomBar(
        primaryColor: _kPrimaryColor,
        secondaryColor: _kSecondaryColor,
        cardColor: _kCardColor,
        textColor: _kTextColor,
      ),
    );
  }
}
