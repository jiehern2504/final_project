import 'workout_plan_models.dart';

/// Rule-based MVP plan builder from user profile + optional chat prompt.
class PlanGenerator {
  static WorkoutPlan buildPlan({
    required String userId,
    required Map<String, dynamic> profile,
    String? userPrompt,
  }) {
    final String activity =
        (profile['activityLevel'] as String?) ?? 'moderate';
    final int dayCount = _dayCountForActivity(activity, userPrompt);
    final List<_TemplateDay> template = _templateForPrompt(userPrompt);

    final List<PlanDay> days = List<PlanDay>.generate(dayCount, (int index) {
      final _TemplateDay source = template[index % template.length];
      return PlanDay(
        dayNumber: index + 1,
        label: 'Day ${index + 1}',
        exercises: source.exercises,
      );
    });

    final String focus = _focusLabel(userPrompt);
    return WorkoutPlan(
      id: '',
      userId: userId,
      title: '$focus · $dayCount-day plan',
      status: WorkoutPlanStatus.draft,
      days: days,
      progress: PlanProgress(completedDays: 0, totalDays: days.length),
      createdAt: DateTime.now(),
    );
  }

  static int _dayCountForActivity(String activity, String? prompt) {
    final String lower = (prompt ?? '').toLowerCase();
    if (lower.contains('3 day') || lower.contains('3-day')) return 3;
    if (lower.contains('7 day') || lower.contains('week')) return 7;
    switch (activity) {
      case 'sedentary':
        return 3;
      case 'light':
        return 4;
      case 'active':
        return 7;
      default:
        return 5;
    }
  }

  static String _focusLabel(String? prompt) {
    final String lower = (prompt ?? '').toLowerCase();
    if (lower.contains('leg') || lower.contains('squat')) {
      return 'Lower body';
    }
    if (lower.contains('push') || lower.contains('chest')) {
      return 'Upper push';
    }
    if (lower.contains('core') || lower.contains('abs')) {
      return 'Core strength';
    }
    return 'Full body';
  }

  static List<_TemplateDay> _templateForPrompt(String? prompt) {
    final String lower = (prompt ?? '').toLowerCase();
    if (lower.contains('leg') || lower.contains('squat')) {
      return _legFocusedDays;
    }
    if (lower.contains('push') || lower.contains('chest')) {
      return _pushFocusedDays;
    }
    return _fullBodyDays;
  }
}

class _TemplateDay {
  const _TemplateDay(this.exercises);
  final List<PlanExercise> exercises;
}

const List<_TemplateDay> _fullBodyDays = <_TemplateDay>[
  _TemplateDay(<PlanExercise>[
    PlanExercise(
      exerciseId: 'bodyweight_squats',
      title: 'Bodyweight Squats',
      setsLabel: '3 × 10–15',
    ),
    PlanExercise(
      exerciseId: 'push_ups',
      title: 'Push-ups',
      setsLabel: '3 × 8–12',
    ),
    PlanExercise(
      exerciseId: 'hand_plank',
      title: 'Hand Plank',
      setsLabel: '3 × 30–45 sec',
    ),
  ]),
  _TemplateDay(<PlanExercise>[
    PlanExercise(
      exerciseId: 'forward_lunges',
      title: 'Forward Lunges',
      setsLabel: '3 × 8–12/side',
    ),
    PlanExercise(
      exerciseId: 'incline_push_ups',
      title: 'Incline Push-ups',
      setsLabel: '3 × 8–15',
    ),
    PlanExercise(
      exerciseId: 'crunches',
      title: 'Crunches',
      setsLabel: '3 × 12–20',
    ),
  ]),
  _TemplateDay(<PlanExercise>[
    PlanExercise(
      exerciseId: 'bulgarian_split_squats',
      title: 'Bulgarian Split Squats',
      setsLabel: '3 × 10–15',
    ),
    PlanExercise(
      exerciseId: 'pike_push_ups',
      title: 'Pike Push-ups',
      setsLabel: '3 × 6–10',
    ),
    PlanExercise(
      exerciseId: 'glute_bridges',
      title: 'Glute Bridges',
      setsLabel: '3 × 10–15',
    ),
  ]),
];

const List<_TemplateDay> _legFocusedDays = <_TemplateDay>[
  _TemplateDay(<PlanExercise>[
    PlanExercise(
      exerciseId: 'bodyweight_squats',
      title: 'Bodyweight Squats',
      setsLabel: '4 × 12–15',
    ),
    PlanExercise(
      exerciseId: 'forward_lunges',
      title: 'Forward Lunges',
      setsLabel: '3 × 10/side',
    ),
  ]),
  _TemplateDay(<PlanExercise>[
    PlanExercise(
      exerciseId: 'bulgarian_split_squats',
      title: 'Bulgarian Split Squats',
      setsLabel: '3 × 10–15',
    ),
    PlanExercise(
      exerciseId: 'glute_bridges',
      title: 'Glute Bridges',
      setsLabel: '3 × 12–15',
    ),
  ]),
];

const List<_TemplateDay> _pushFocusedDays = <_TemplateDay>[
  _TemplateDay(<PlanExercise>[
    PlanExercise(
      exerciseId: 'push_ups',
      title: 'Push-ups',
      setsLabel: '4 × 8–12',
    ),
    PlanExercise(
      exerciseId: 'incline_push_ups',
      title: 'Incline Push-ups',
      setsLabel: '3 × 10–15',
    ),
  ]),
  _TemplateDay(<PlanExercise>[
    PlanExercise(
      exerciseId: 'pike_push_ups',
      title: 'Pike Push-ups',
      setsLabel: '3 × 6–10',
    ),
    PlanExercise(
      exerciseId: 'diamond_knee_push_ups',
      title: 'Diamond Knee Push-ups',
      setsLabel: '3 × 8–12',
    ),
  ]),
];
