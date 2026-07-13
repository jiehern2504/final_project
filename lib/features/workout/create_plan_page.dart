import 'package:flutter/material.dart';

import '../../core/notifications/workout_reminder_service.dart';
import '../planner/pages/ai_chat_page.dart';
import '../planner/user_preferences_repository.dart';
import '../planner/models/workout_plan_models.dart';
import '../planner/repositories/workout_plan_repository.dart';
import 'exercise_picker_sheet.dart';
import 'workout_time_picker_sheet.dart';

part 'widgets/stepper_row.dart';

const Color _kPrimaryColor = Color(0xFF4CAF50);
const Color _kBackgroundColor = Color(0xFFF9FBF9);
const Color _kTextColor = Color(0xFF333333);

enum _CreateStep { gate, builder, workoutTime }

/// How long the manual plan runs.
enum _PlanLength { oneWeek, oneMonth }

/// When the plan is a month, how the 4 weeks are built.
enum _MonthMode { repeatWeek, customWeeks }

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

  /// Days grouped by week. Week 1 always exists; extra weeks are only used in
  /// the "1 month · custom weeks" mode.
  final List<List<_BuilderDay>> _weeks = <List<_BuilderDay>>[
    <_BuilderDay>[_BuilderDay(label: 'Day 1')],
  ];

  _PlanLength _length = _PlanLength.oneWeek;
  _MonthMode _monthMode = _MonthMode.repeatWeek;
  bool _saving = false;

  /// True when the user is hand-building 4 different weeks.
  bool get _isCustomWeeks =>
      _length == _PlanLength.oneMonth && _monthMode == _MonthMode.customWeeks;

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
        builder: (BuildContext context) => const AiChatPage(
          initialMessage: 'help me to build workout plan',
        ),
      ),
    );
  }

  void _chooseManual() {
    setState(() => _step = _CreateStep.builder);
  }

  /// A week may have at most 7 days.
  static const int _kMaxDays = 7;

  /// A week must have at least 3 days to be worth training.
  static const int _kMinDays = 3;

  /// A one-month plan is 4 weeks.
  static const int _kCustomWeeks = 4;

  /// Switches the plan length, padding [_weeks] to 4 when a month is chosen.
  void _setLength(_PlanLength length) {
    setState(() {
      _length = length;
      if (length == _PlanLength.oneMonth) {
        while (_weeks.length < _kCustomWeeks) {
          _weeks.add(<_BuilderDay>[_BuilderDay(label: 'Day 1')]);
        }
      }
    });
  }

  void _addDay(int weekIndex) {
    final List<_BuilderDay> days = _weeks[weekIndex];
    if (days.length >= _kMaxDays) return;
    setState(() {
      days.add(_BuilderDay(label: 'Day ${days.length + 1}'));
    });
  }

  void _removeDay(int weekIndex, int dayIndex) {
    final List<_BuilderDay> days = _weeks[weekIndex];
    if (days.length <= 1) return;
    setState(() {
      final List<List<PlanExercise>> exerciseLists = days
          .map((d) => List<PlanExercise>.from(d.exercises))
          .toList()
        ..removeAt(dayIndex);
      days
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

  Future<void> _addExercise(int weekIndex, int dayIndex) async {
    final PlanExercise? picked = await showExercisePickerSheet(context);
    if (picked == null || !mounted) return;
    // Normalise to a fixed "N sets × M reps" format so only the numbers can be
    // edited later (never the words).
    final (int sets, int reps) = _parseSetsReps(picked.setsLabel);
    setState(() {
      _weeks[weekIndex][dayIndex].exercises.add(
        PlanExercise(
          exerciseId: picked.exerciseId,
          title: picked.title,
          setsLabel: _formatSetsReps(sets, reps),
        ),
      );
    });
  }

  void _removeExercise(int weekIndex, int dayIndex, int exerciseIndex) {
    setState(
      () => _weeks[weekIndex][dayIndex].exercises.removeAt(exerciseIndex),
    );
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
  Future<void> _editSetsLabel(
    int weekIndex,
    int dayIndex,
    int exerciseIndex,
  ) async {
    final PlanExercise exercise =
        _weeks[weekIndex][dayIndex].exercises[exerciseIndex];
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
      _weeks[weekIndex][dayIndex].exercises[exerciseIndex] = PlanExercise(
        exerciseId: exercise.exerciseId,
        title: exercise.title,
        setsLabel: _formatSetsReps(sets, reps),
      );
    });
  }

  /// The weeks whose content the user actually authored. In "repeat" mode only
  /// Week 1 is authored (it gets copied ×4 on save); in "custom" mode all 4.
  List<List<_BuilderDay>> get _sourceWeeks =>
      _isCustomWeeks ? _weeks.sublist(0, _kCustomWeeks) : <List<_BuilderDay>>[_weeks[0]];

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToWorkoutTimeStep() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('Enter a plan title.');
      return;
    }

    final List<List<_BuilderDay>> weeks = _sourceWeeks;
    final bool multi = weeks.length > 1;
    for (int w = 0; w < weeks.length; w++) {
      final List<_BuilderDay> days = weeks[w];
      final String where = multi ? 'Week ${w + 1}: ' : '';
      if (days.length < _kMinDays) {
        _showError('${where}a plan needs at least 3 days. Add more days.');
        return;
      }
      if (days.any((d) => !d.isRest && d.exercises.isEmpty)) {
        _showError(
          '${where}add exercises to each workout day, or mark it as a rest day.',
        );
        return;
      }
      if (!days.any((d) => !d.isRest && d.exercises.isNotEmpty)) {
        _showError('${where}add at least one workout day.');
        return;
      }
    }
    setState(() => _step = _CreateStep.workoutTime);
  }

  /// Converts one authored week into savable [PlanDay]s (days numbered 1..N).
  List<PlanDay> _toPlanDays(List<_BuilderDay> week) {
    return List<PlanDay>.generate(week.length, (int i) {
      final _BuilderDay d = week[i];
      return PlanDay(
        dayNumber: i + 1,
        label: d.label,
        isRest: d.isRest,
        exercises: d.isRest
            ? const <PlanExercise>[]
            : List<PlanExercise>.from(d.exercises),
      );
    });
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
      final String title = _titleController.text.trim();
      if (_length == _PlanLength.oneWeek) {
        await _planRepository.saveManualPlan(
          title: title,
          days: _toPlanDays(_weeks[0]),
        );
      } else {
        final List<List<PlanDay>> weekDays;
        if (_monthMode == _MonthMode.repeatWeek) {
          final List<PlanDay> oneWeek = _toPlanDays(_weeks[0]);
          weekDays =
              List<List<PlanDay>>.generate(_kCustomWeeks, (_) => oneWeek);
        } else {
          weekDays = List<List<PlanDay>>.generate(
            _kCustomWeeks,
            (int w) => _toPlanDays(_weeks[w]),
          );
        }
        await _planRepository.saveManualSeries(title: title, weeks: weekDays);
      }

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
        _lengthSelector(),
        if (_length == _PlanLength.oneMonth) ...[
          const SizedBox(height: 16),
          _monthModeSelector(),
        ],
        const SizedBox(height: 16),
        if (_isCustomWeeks)
          ...List<Widget>.generate(
            _kCustomWeeks,
            (int w) => _weekBlock(w, header: 'Week ${w + 1}', grouped: true),
          )
        else ...[
          if (_length == _PlanLength.oneMonth) _repeatNote(),
          _weekBlock(0, header: 'Workout days'),
        ],
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

  Widget _lengthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plan length',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<_PlanLength>(
          segments: const <ButtonSegment<_PlanLength>>[
            ButtonSegment<_PlanLength>(
              value: _PlanLength.oneWeek,
              label: Text('1 week'),
              icon: Icon(Icons.view_week_outlined),
            ),
            ButtonSegment<_PlanLength>(
              value: _PlanLength.oneMonth,
              label: Text('1 month'),
              icon: Icon(Icons.calendar_month_outlined),
            ),
          ],
          selected: <_PlanLength>{_length},
          onSelectionChanged: (Set<_PlanLength> s) => _setLength(s.first),
        ),
      ],
    );
  }

  Widget _monthModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to fill the month',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<_MonthMode>(
          segments: const <ButtonSegment<_MonthMode>>[
            ButtonSegment<_MonthMode>(
              value: _MonthMode.repeatWeek,
              label: Text('Repeat 1 week'),
            ),
            ButtonSegment<_MonthMode>(
              value: _MonthMode.customWeeks,
              label: Text('4 custom weeks'),
            ),
          ],
          selected: <_MonthMode>{_monthMode},
          onSelectionChanged: (Set<_MonthMode> s) =>
              setState(() => _monthMode = s.first),
        ),
      ],
    );
  }

  Widget _repeatNote() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: _kPrimaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This week repeats for 4 weeks. Finish each week to unlock the next.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders one week: a header (with "Add day") plus its day cards. When
  /// [grouped] is true the block is boxed so the 4 custom weeks are distinct.
  Widget _weekBlock(int weekIndex, {required String header, bool grouped = false}) {
    final List<_BuilderDay> days = _weeks[weekIndex];
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              header,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: days.length >= _kMaxDays ? null : () => _addDay(weekIndex),
              icon: const Icon(Icons.add),
              label: const Text('Add day'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List<Widget>.generate(
          days.length,
          (int dayIndex) => _dayCard(weekIndex, dayIndex),
        ),
      ],
    );

    if (!grouped) return content;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.3)),
      ),
      child: content,
    );
  }

  Widget _dayCard(int weekIndex, int dayIndex) {
    final _BuilderDay day = _weeks[weekIndex][dayIndex];
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
                      setState(() => _weeks[weekIndex][dayIndex].isRest = v),
                ),
                if (_weeks[weekIndex].length > 1)
                  IconButton(
                    onPressed: () => _removeDay(weekIndex, dayIndex),
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
                    onTap: () => _editSetsLabel(weekIndex, dayIndex, ei),
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
                    onPressed: () => _removeExercise(weekIndex, dayIndex, ei),
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () => _addExercise(weekIndex, dayIndex),
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
            ],
          ],
        ),
      ),
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

