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
        await _showCompletionPrompt(plan);
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
          'Your achievements and badges are based on completed days, so they '
          'will be reset too. This cannot be undone.',
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
                const SizedBox(height: 16),
                if (plan.progress.totalDays > 0 &&
                    plan.progress.completedDays >= plan.progress.totalDays)
                  _CompletionBanner(
                    onRepeat: () => _repeatPlan(plan),
                    onNewPlan: () => _goToNewPlan(plan),
                  )
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
                ...plan.days.map((PlanDay day) {
                  return _DayCard(
                    day: day,
                    planStarted: plan.isStarted,
                    isMarking: _markingDays.contains(day.dayNumber),
                    onMarkComplete: plan.isStarted && !day.completed
                        ? () => _markDay(plan, day.dayNumber)
                        : null,
                    onExerciseTap: _openExercise,
                  );
                }),
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
    required this.onExerciseTap,
  });

  final PlanDay day;
  final bool planStarted;
  final bool isMarking;
  final VoidCallback? onMarkComplete;
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
                  ),
              ],
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
