import 'package:flutter/material.dart';

import '../planner/models/workout_plan_models.dart';
import '../planner/repositories/workout_plan_repository.dart';
import '../workout/create_plan_page.dart';
import '../workout/workout_plan_page.dart';
import '../tutorial/exercise_catalog.dart';
import '../tutorial/exercise_detail_page.dart';

const Color _kPrimaryColor = Color(0xFF4CAF50);

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key, this.repository});

  final WorkoutPlanRepository? repository;

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late final WorkoutPlanRepository _repository;
  bool _starting = false;
  final Set<int> _markingDays = <int>{};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WorkoutPlanRepository();
  }

  Future<void> _startPlan(WorkoutPlan plan) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await _repository.startPlan(plan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan started. Good luck!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start plan. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _markDay(WorkoutPlan plan, int dayNumber) async {
    if (_markingDays.contains(dayNumber)) return;
    setState(() => _markingDays.add(dayNumber));
    try {
      await _repository.markDayComplete(plan.id, dayNumber);
      // This day wasn't complete before, so +1. If that finishes the plan, ask
      // the user what to do next instead of silently archiving it.
      final bool nowComplete = plan.progress.totalDays > 0 &&
          plan.progress.completedDays + 1 >= plan.progress.totalDays;
      if (nowComplete && mounted) {
        if (plan.isSeries && plan.weekNumber < plan.totalWeeks) {
          await _showWeekCompletePrompt(plan);
        } else {
          // Finishing the whole plan — nudge the user to update their stats.
          await _promptUpdateBodyMetrics();
          if (!mounted) return;
          await _showCompletionPrompt(plan);
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not mark day complete.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _markingDays.remove(dayNumber));
      }
    }
  }

  /// Asks the user what to do when a plan is finished: repeat it or start a new
  /// one. Chosen instead of silently resetting/archiving the plan.
  Future<void> _showCompletionPrompt(WorkoutPlan plan) async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Plan complete! 🎉'),
        content: const Text(
          'You finished every day in this plan.\n\n'
          'Keep this plan and do it again, or start a new one?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('later'),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('again'),
            child: const Text('Do it again'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('new'),
            child: const Text('New plan'),
          ),
        ],
      ),
    );
    if (choice == 'again') {
      await _repeatPlan(plan);
    } else if (choice == 'new') {
      await _goToNewPlan(plan);
    }
  }

  /// The earliest day the user still has to complete (null when all done).
  /// Marking is only allowed on this day, so days can't be done out of order.
  int? _firstIncompleteDayNumber(WorkoutPlan plan) {
    final List<PlanDay> days = <PlanDay>[...plan.days]
      ..sort((PlanDay a, PlanDay b) => a.dayNumber.compareTo(b.dayNumber));
    for (final PlanDay d in days) {
      if (!d.completed) return d.dayNumber;
    }
    return null;
  }

  /// True when a day was already marked complete today (blocks a second one).
  bool _isMarkedToday(WorkoutPlan plan) {
    final DateTime? last = plan.lastMarkedAt;
    if (last == null) return false;
    final DateTime now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// After finishing a plan, reminds the user to update their weight/height.
  Future<void> _promptUpdateBodyMetrics() async {
    Map<String, dynamic>? profile;
    try {
      profile = await _repository.fetchUserProfile();
    } catch (_) {
      profile = null;
    }
    if (!mounted) return;

    final TextEditingController weightCtrl = TextEditingController(
      text: _asDouble(profile?['weight'])?.toString() ?? '',
    );
    final TextEditingController heightCtrl = TextEditingController(
      text: _asDouble(profile?['height'])?.toString() ?? '',
    );

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Update your stats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nice work finishing your plan! Keep your weight and height up '
              'to date for better recommendations.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                prefixIcon: Icon(Icons.monitor_weight_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: heightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                prefixIcon: Icon(Icons.height),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save == true) {
      final double? w = double.tryParse(weightCtrl.text.trim());
      final double? h = double.tryParse(heightCtrl.text.trim());
      if (w != null && h != null && w >= 25 && w <= 350 && h >= 80 && h <= 260) {
        try {
          await _repository.updateBodyMetrics(weight: w, height: h);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Stats updated.')),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not update stats. Try again later.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter a valid weight (25–350 kg) and height (80–260 cm).',
            ),
          ),
        );
      }
    }

    weightCtrl.dispose();
    heightCtrl.dispose();
  }

  /// Asks whether to start the next week after finishing a week in a series.
  Future<void> _showWeekCompletePrompt(WorkoutPlan plan) async {
    final int nextWeek = plan.weekNumber + 1;
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Week ${plan.weekNumber} complete! 🎉'),
        content: Text(
          'Great work finishing Week ${plan.weekNumber} of ${plan.totalWeeks}.\n\n'
          'Start Week $nextWeek now, or take a break and start it later?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('later'),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('next'),
            child: Text('Start Week $nextWeek'),
          ),
        ],
      ),
    );
    if (choice == 'next') {
      await _advanceWeek(plan);
    }
  }

  /// Completes the current week and unlocks/activates the next one.
  Future<void> _advanceWeek(WorkoutPlan plan) async {
    try {
      await _repository.advanceToNextWeek(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Week ${plan.weekNumber + 1} unlocked. Good luck!'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start the next week. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _repeatPlan(WorkoutPlan plan) async {
    try {
      await _repository.resetPlanProgress(plan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan restarted. Good luck!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not restart the plan. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Archives the finished plan (so it leaves the active slot) and opens the
  /// create-plan flow so the user can actually build a new one.
  Future<void> _goToNewPlan(WorkoutPlan plan) async {
    try {
      await _repository.archivePlan(plan.id);
    } catch (_) {
      // Non-fatal — still let them create a new plan.
    }
    if (!mounted) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const CreatePlanPage(),
      ),
    );
  }

  Future<void> _confirmDelete(WorkoutPlan plan) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete this plan?'),
        content: const Text(
          'This permanently deletes the current plan and all of its progress. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.deletePlan(plan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the plan. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmReset(WorkoutPlan plan) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This sets every completed day back to 0 for this plan.\n\n'
          'Your lifetime achievements and summary history are kept — only '
          'this plan\'s day check-offs are cleared. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.resetPlanProgress(plan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress and achievements reset.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not reset progress. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openExercise(String exerciseId) {
    final TutorialExercise? exercise = findExerciseById(exerciseId);
    if (exercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exercise "$exerciseId" not found in catalog.')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ExerciseDetailPage(
          exercise: exercise,
          primaryColor: _kPrimaryColor,
        ),
      ),
    );
  }

  /// Builds the day cards, gating "Mark done" so days are completed strictly
  /// in order and at most one per calendar day.
  List<Widget> _dayCards(WorkoutPlan plan) {
    final int? nextDay = _firstIncompleteDayNumber(plan);
    final bool markedToday = _isMarkedToday(plan);
    return plan.days.map((PlanDay day) {
      final bool isNext = day.dayNumber == nextDay;
      final bool canMark =
          plan.isStarted && !day.completed && isNext && !markedToday;
      String? lockHint;
      if (plan.isStarted && !day.completed && !canMark) {
        lockHint = (isNext && markedToday)
            ? 'Come back tomorrow for your next day.'
            : 'Finish the earlier days first.';
      }
      return _DayCard(
        day: day,
        planStarted: plan.isStarted,
        isMarking: _markingDays.contains(day.dayNumber),
        onMarkComplete: canMark ? () => _markDay(plan, day.dayNumber) : null,
        lockHint: lockHint,
        onExerciseTap: _openExercise,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('Your Progress'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<WorkoutPlan?>(
          stream: _repository.watchCurrentPlan(),
          builder: (BuildContext context, AsyncSnapshot<WorkoutPlan?> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final WorkoutPlan? plan = snapshot.data;
            if (plan == null) {
              return _EmptyProgressState(
                onGoToWorkoutPlan: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const WorkoutPlanPage(),
                    ),
                  );
                },
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Text(
                  plan.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${plan.progress.completedDays}/${plan.progress.totalDays} days completed',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                if (plan.totalWeeks > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Week ${plan.weekNumber} of ${plan.totalWeeks}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _kPrimaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                if (plan.progress.totalDays > 0 &&
                    plan.progress.completedDays >= plan.progress.totalDays)
                  (plan.isSeries && plan.weekNumber < plan.totalWeeks
                      ? _WeekAdvanceBanner(
                          nextWeek: plan.weekNumber + 1,
                          totalWeeks: plan.totalWeeks,
                          onStartNext: () => _advanceWeek(plan),
                        )
                      : _CompletionBanner(
                          onRepeat: () => _repeatPlan(plan),
                          onNewPlan: () => _goToNewPlan(plan),
                        ))
                else if (!plan.isStarted)
                  FilledButton.icon(
                    onPressed: _starting ? null : () => _startPlan(plan),
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(_starting ? 'Starting…' : 'Start plan'),
                  )
                else
                  Chip(
                    avatar: Icon(
                      Icons.check_circle,
                      color: _kPrimaryColor,
                      size: 18,
                    ),
                    label: const Text('Plan in progress'),
                  ),
                const SizedBox(height: 20),
                ..._dayCards(plan),
                if (plan.isStarted) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _confirmReset(plan),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reset progress'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(plan),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete plan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.onRepeat, required this.onNewPlan});

  final VoidCallback onRepeat;
  final VoidCallback onNewPlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPrimaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: _kPrimaryColor),
              const SizedBox(width: 8),
              Text(
                'Plan complete!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Nice work — you finished every day. Do it again, or start a '
            'new plan?',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRepeat,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimaryColor,
                    side: const BorderSide(color: _kPrimaryColor),
                  ),
                  child: const Text('Do it again'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onNewPlan,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                  ),
                  child: const Text('New plan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekAdvanceBanner extends StatelessWidget {
  const _WeekAdvanceBanner({
    required this.nextWeek,
    required this.totalWeeks,
    required this.onStartNext,
  });

  final int nextWeek;
  final int totalWeeks;
  final VoidCallback onStartNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPrimaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: _kPrimaryColor),
              const SizedBox(width: 8),
              Text(
                'Week done!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Nice work — you finished this week. Ready for Week $nextWeek '
            'of $totalWeeks?',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStartNext,
              style: FilledButton.styleFrom(backgroundColor: _kPrimaryColor),
              child: Text('Start Week $nextWeek'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProgressState extends StatelessWidget {
  const _EmptyProgressState({required this.onGoToWorkoutPlan});

  final VoidCallback onGoToWorkoutPlan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No active plan yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create or view your workout plan to start tracking progress.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onGoToWorkoutPlan,
              child: const Text('Go to Workout Plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.planStarted,
    required this.isMarking,
    required this.onMarkComplete,
    required this.lockHint,
    required this.onExerciseTap,
  });

  final PlanDay day;
  final bool planStarted;
  final bool isMarking;
  final VoidCallback? onMarkComplete;

  /// When the day can't be marked yet, why (e.g. out of order, or already did
  /// one today). Null when the day is markable or already complete.
  final String? lockHint;

  final void Function(String exerciseId) onExerciseTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  day.completed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: day.completed ? _kPrimaryColor : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    day.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (planStarted && onMarkComplete != null)
                  TextButton(
                    onPressed: isMarking ? null : onMarkComplete,
                    child: isMarking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mark done'),
                  )
                else if (planStarted && !day.completed && lockHint != null)
                  const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
              ],
            ),
            if (planStarted && !day.completed && lockHint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  lockHint!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 10),
            if (day.isRest)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.bedtime_outlined, color: _kPrimaryColor),
                    SizedBox(width: 8),
                    Text('Rest day'),
                  ],
                ),
              )
            else
              ...day.exercises.map((PlanExercise exercise) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_outline),
                  title: Text(exercise.title),
                  subtitle: Text(exercise.setsLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onExerciseTap(exercise.exerciseId),
                );
              }),
          ],
        ),
      ),
    );
  }
}
