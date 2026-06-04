import 'package:flutter/material.dart';

import '../../core/notifications/workout_reminder_service.dart';
import '../planner/ai_chat_page.dart';
import '../planner/user_preferences_repository.dart';
import '../planner/workout_plan_models.dart';
import '../planner/workout_plan_repository.dart';
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

  void _addDay() {
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
    setState(() => _days[dayIndex].exercises.add(picked));
  }

  void _removeExercise(int dayIndex, int exerciseIndex) {
    setState(() => _days[dayIndex].exercises.removeAt(exerciseIndex));
  }

  Future<void> _editSetsLabel(int dayIndex, int exerciseIndex) async {
    final PlanExercise exercise = _days[dayIndex].exercises[exerciseIndex];
    final TextEditingController controller =
        TextEditingController(text: exercise.setsLabel);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Sets / reps'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. 3 sets • 8–12 reps',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || !mounted) return;
    setState(() {
      _days[dayIndex].exercises[exerciseIndex] = PlanExercise(
        exerciseId: exercise.exerciseId,
        title: exercise.title,
        setsLabel: result,
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
    final bool hasExercise =
        _days.any((d) => d.exercises.isNotEmpty);
    if (!hasExercise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise.')),
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
            exercises: List<PlanExercise>.from(_days[i].exercises),
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
    return Scaffold(
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
              onPressed: _addDay,
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
                      if (_days.length > 1)
                        IconButton(
                          onPressed: () => _removeDay(dayIndex),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove day',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
