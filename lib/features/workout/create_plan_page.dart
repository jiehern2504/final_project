import 'package:flutter/material.dart';

import '../../core/notifications/workout_reminder_service.dart';
import '../planner/pages/ai_chat_page.dart';
import '../planner/user_preferences_repository.dart';
import '../planner/models/workout_plan_models.dart';
import '../planner/repositories/workout_plan_repository.dart';
import 'exercise_picker_sheet.dart';
import 'workout_time_picker_sheet.dart';

const Color _kPrimaryColor = Color(0xFF4CAF50);
const Color _kBackgroundColor = Color(0xFFF9FBF9);
const Color _kTextColor = Color(0xFF333333);

enum _CreateStep { gate, builder, workoutTime }

class _BuilderDay {
  _BuilderDay({required this.label})
      : exercises = <PlanExercise>[];

  final String label;
  final List<PlanExercise> exercises;
  bool isRest = false;
}

class CreatePlanPage extends StatefulWidget {
  const CreatePlanPage({
    super.key,
    this.planRepository,
    this.preferencesRepository,
  });

  final WorkoutPlanRepository? planRepository;
  final UserPreferencesRepository? preferencesRepository;

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  late final WorkoutPlanRepository _planRepository;
  late final UserPreferencesRepository _prefsRepository;

  _CreateStep _step = _CreateStep.gate;
  final TextEditingController _titleController =
      TextEditingController(text: 'My workout plan');
  final List<_BuilderDay> _days = <_BuilderDay>[_BuilderDay(label: 'Day 1')];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _planRepository = widget.planRepository ?? WorkoutPlanRepository();
    _prefsRepository =
        widget.preferencesRepository ?? UserPreferencesRepository();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _chooseAiHelp() {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AiChatPage(),
      ),
    );
  }

  void _chooseManual() {
    setState(() => _step = _CreateStep.builder);
  }

  /// A plan may have at most 7 days (one week).
  static const int _kMaxDays = 7;

  /// A plan must have at least 3 days to be worth training.
  static const int _kMinDays = 3;

  void _addDay() {
    if (_days.length >= _kMaxDays) return;
    setState(() {
      _days.add(_BuilderDay(label: 'Day ${_days.length + 1}'));
    });
  }

  void _removeDay(int index) {
    if (_days.length <= 1) return;
    setState(() {
      final List<List<PlanExercise>> exerciseLists = _days
          .map((d) => List<PlanExercise>.from(d.exercises))
          .toList()
        ..removeAt(index);
      _days
        ..clear()
        ..addAll(
          List<_BuilderDay>.generate(
            exerciseLists.length,
            (int i) => _BuilderDay(label: 'Day ${i + 1}')
              ..exercises.addAll(exerciseLists[i]),
          ),
        );
    });
  }

  Future<void> _addExercise(int dayIndex) async {
    final PlanExercise? picked = await showExercisePickerSheet(context);
    if (picked == null || !mounted) return;
    // Normalise to a fixed "N sets × M reps" format so only the numbers can be
    // edited later (never the words).
    final (int sets, int reps) = _parseSetsReps(picked.setsLabel);
    setState(() {
      _days[dayIndex].exercises.add(
        PlanExercise(
          exerciseId: picked.exerciseId,
          title: picked.title,
          setsLabel: _formatSetsReps(sets, reps),
        ),
      );
    });
  }

  void _removeExercise(int dayIndex, int exerciseIndex) {
    setState(() => _days[dayIndex].exercises.removeAt(exerciseIndex));
  }

  /// Formats the fixed label — the words "sets" and "reps" are never editable.
  String _formatSetsReps(int sets, int reps) => '$sets sets × $reps reps';

  /// Extracts the sets/reps numbers from any existing label (defaults 3 × 12).
  (int, int) _parseSetsReps(String label) {
    final List<int> nums = RegExp(r'\d+')
        .allMatches(label)
        .map((RegExpMatch m) => int.parse(m.group(0)!))
        .toList();
    final int sets = (nums.isNotEmpty ? nums.first : 3).clamp(1, 10);
    final int reps = (nums.length >= 2 ? nums.last : 12).clamp(1, 100);
    return (sets, reps);
  }

  /// Lets the user change ONLY the sets and reps numbers via steppers.
  Future<void> _editSetsLabel(int dayIndex, int exerciseIndex) async {
    final PlanExercise exercise = _days[dayIndex].exercises[exerciseIndex];
    final (int startSets, int startReps) = _parseSetsReps(exercise.setsLabel);
    int sets = startSets;
    int reps = startReps;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Sets & reps'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperRow(
                  label: 'Sets',
                  value: sets,
                  min: 1,
                  max: 10,
                  onChanged: (int v) => setDialogState(() => sets = v),
                ),
                const SizedBox(height: 8),
                _StepperRow(
                  label: 'Reps',
                  value: reps,
                  min: 1,
                  max: 100,
                  onChanged: (int v) => setDialogState(() => reps = v),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    setState(() {
      _days[dayIndex].exercises[exerciseIndex] = PlanExercise(
        exerciseId: exercise.exerciseId,
        title: exercise.title,
        setsLabel: _formatSetsReps(sets, reps),
      );
    });
  }

  void _goToWorkoutTimeStep() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a plan title.')),
      );
      return;
    }
    if (_days.length < _kMinDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A plan needs at least 3 days. Add more days before continuing.',
          ),
        ),
      );
      return;
    }
    final bool emptyWorkoutDay =
        _days.any((d) => !d.isRest && d.exercises.isEmpty);
    if (emptyWorkoutDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add exercises to each workout day, or mark it as a rest day.',
          ),
        ),
      );
      return;
    }
    final bool hasWorkout =
        _days.any((d) => !d.isRest && d.exercises.isNotEmpty);
    if (!hasWorkout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one workout day.')),
      );
      return;
    }
    setState(() => _step = _CreateStep.workoutTime);
  }

  Future<void> _savePlan() async {
    final WorkoutTimePickerResult? timeResult =
        await showWorkoutTimePickerSheet(
      context,
      initialReminderEnabled: true,
      requireTimeWhenEnabled: true,
    );
    if (timeResult == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final List<PlanDay> planDays = <PlanDay>[];
      for (int i = 0; i < _days.length; i++) {
        planDays.add(
          PlanDay(
            dayNumber: i + 1,
            label: _days[i].label,
            isRest: _days[i].isRest,
            exercises: _days[i].isRest
                ? const <PlanExercise>[]
                : List<PlanExercise>.from(_days[i].exercises),
          ),
        );
      }

      await _planRepository.saveManualPlan(
        title: _titleController.text.trim(),
        days: planDays,
      );

      await _prefsRepository.saveWorkoutReminder(
        enabled: timeResult.reminderEnabled,
        hour: timeResult.hour,
        minute: timeResult.minute,
      );

      if (timeResult.reminderEnabled && timeResult.hasTime) {
        final bool granted = await WorkoutReminderService.instance
            .ensureReminderPermissions();
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Enable notifications and Alarms & reminders (exact alarms) '
                'in settings to receive workout reminders at your chosen time.',
              ),
            ),
          );
        } else {
          await WorkoutReminderService.instance.scheduleDailyReminder(
            hour: timeResult.hour!,
            minute: timeResult.minute!,
          );
        }
      } else {
        await WorkoutReminderService.instance.cancelReminder();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan saved as draft.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save plan. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only the first step may leave the page. On later steps, "back" steps
    // backwards through the flow so the plan the user built is not lost.
    return PopScope(
      canPop: _step == _CreateStep.gate,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        setState(() {
          _step = switch (_step) {
            _CreateStep.workoutTime => _CreateStep.builder,
            _CreateStep.builder => _CreateStep.gate,
            _CreateStep.gate => _CreateStep.gate,
          };
        });
      },
      child: Scaffold(
        backgroundColor: _kBackgroundColor,
        appBar: AppBar(
          title: Text(_appBarTitle),
          centerTitle: true,
        ),
        body: SafeArea(
          child: switch (_step) {
            _CreateStep.gate => _buildGate(),
            _CreateStep.builder => _buildBuilder(),
            _CreateStep.workoutTime => _buildWorkoutTimePrompt(),
          },
        ),
      ),
    );
  }

  String get _appBarTitle {
    return switch (_step) {
      _CreateStep.gate => 'Create a plan',
      _CreateStep.builder => 'Build your plan',
      _CreateStep.workoutTime => 'Workout time',
    };
  }

  Widget _buildGate() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Would you like AI to help build your plan, or choose exercises yourself from our tutorial library?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _kTextColor,
                  height: 1.4,
                ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _chooseAiHelp,
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.smart_toy_outlined),
            label: const Text('Yes, I want AI help'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _chooseManual,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: _kPrimaryColor,
              side: const BorderSide(color: _kPrimaryColor),
            ),
            child: const Text('No, I\'ll build it myself'),
          ),
        ],
      ),
    );
  }

  Widget _buildBuilder() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Plan title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Workout days',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _days.length >= _kMaxDays ? null : _addDay,
              icon: const Icon(Icons.add),
              label: const Text('Add day'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List<Widget>.generate(_days.length, (int dayIndex) {
          final _BuilderDay day = _days[dayIndex];
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          day.label,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Text(
                        'Rest',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      Switch(
                        value: day.isRest,
                        activeThumbColor: _kPrimaryColor,
                        onChanged: (bool v) =>
                            setState(() => _days[dayIndex].isRest = v),
                      ),
                      if (_days.length > 1)
                        IconButton(
                          onPressed: () => _removeDay(dayIndex),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove day',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (day.isRest)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.bedtime_outlined, color: _kPrimaryColor),
                          SizedBox(width: 8),
                          Text('Rest day — no exercises'),
                        ],
                      ),
                    )
                  else ...[
                    ...List<Widget>.generate(day.exercises.length, (int ei) {
                      final PlanExercise ex = day.exercises[ei];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ex.title),
                        subtitle: GestureDetector(
                          onTap: () => _editSetsLabel(dayIndex, ei),
                          child: Text(
                            ex.setsLabel,
                            style: TextStyle(
                              color: _kPrimaryColor.withValues(alpha: 0.9),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeExercise(dayIndex, ei),
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => _addExercise(dayIndex),
                      icon: const Icon(Icons.add),
                      label: const Text('Add exercise'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : _goToWorkoutTimeStep,
          style: FilledButton.styleFrom(
            backgroundColor: _kPrimaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildWorkoutTimePrompt() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'When do you usually work out?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Set a daily reminder time, or turn reminders off. You can change this later on your Workout Plan page.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _saving ? null : _savePlan,
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save plan'),
          ),
        ],
      ),
    );
  }
}

/// A fixed-label number stepper (e.g. "Sets  [-] 3 [+]"). The label text is not
/// editable — only the number changes.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: _kPrimaryColor,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
          color: _kPrimaryColor,
        ),
      ],
    );
  }
}
