import 'package:flutter/material.dart';

import '../planner/models/workout_plan_models.dart';
import '../planner/repositories/workout_plan_repository.dart';
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
                if (!plan.isStarted)
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
              ],
            );
          },
        ),
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
