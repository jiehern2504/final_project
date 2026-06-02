import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notifications/workout_reminder_service.dart';

import '../planner/ai_chat_page.dart';

import '../planner/user_preferences_repository.dart';

import '../planner/workout_plan_models.dart';

import '../planner/workout_plan_repository.dart';

import '../progress/progress_page.dart';

import 'create_plan_page.dart';

import 'workout_time_picker_sheet.dart';

const Color _kPrimaryColor = Color(0xFF4CAF50);

const Color _kSecondaryColor = Color(0xFFFFB74D);

const Color _kBackgroundColor = Color(0xFFF9FBF9);

const Color _kCardColor = Colors.white;

const Color _kTextColor = Color(0xFF333333);

Color _withOpacity(Color color, double opacity) {
  final int a = (opacity * 255).round().clamp(0, 255);

  return color.withAlpha(a);
}

void _openAiChat(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const AiChatPage(),
    ),
  );
}

void _openCreatePlan(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const CreatePlanPage(),
    ),
  );
}

void _openProgress(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const ProgressPage(),
    ),
  );
}

class WorkoutPlanPage extends StatefulWidget {
  const WorkoutPlanPage({
    super.key,

    this.repository,

    this.preferencesRepository,
  });

  final WorkoutPlanRepository? repository;

  final UserPreferencesRepository? preferencesRepository;

  @override
  State<WorkoutPlanPage> createState() => _WorkoutPlanPageState();
}

class _WorkoutPlanPageState extends State<WorkoutPlanPage> {
  late final WorkoutPlanRepository _repository;

  late final UserPreferencesRepository _prefsRepository;

  bool _starting = false;

  bool _aiPromptDismissed = false;

  bool _savingReminder = false;

  String _errorMessage(Object error) {
    if (error is StateError) return error.message;
    if (error is PlatformException) {
      final String? message = error.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      return error.code;
    }
    final String message = error.toString().trim();
    if (message.isEmpty || message == 'Exception') {
      return 'Unknown error';
    }
    return message;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void initState() {
    super.initState();

    _repository = widget.repository ?? WorkoutPlanRepository();

    _prefsRepository =
        widget.preferencesRepository ?? UserPreferencesRepository();
  }

  Future<void> _startPlan(WorkoutPlan plan) async {
    if (_starting) return;

    setState(() => _starting = true);

    try {
      await _repository.startPlan(plan.id);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan started. Good luck!')));
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

  Future<void> _editReminderTime(WorkoutReminderPrefs prefs) async {
    final TimeOfDay? initialTime = prefs.hasTime
        ? TimeOfDay(hour: prefs.hour!, minute: prefs.minute!)
        : null;

    final WorkoutTimePickerResult? result = await showWorkoutTimePickerSheet(
      context,

      initialReminderEnabled: prefs.enabled,

      initialTime: initialTime,

      requireTimeWhenEnabled: true,
    );

    if (result == null || !mounted) return;

    await _applyReminderResult(result);
  }

  Future<void> _toggleReminder(bool enabled, WorkoutReminderPrefs prefs) async {
    if (_savingReminder) return;

    if (enabled && !prefs.hasTime) {
      await _editReminderTime(prefs.copyWithEnabled(enabled: true));

      return;
    }

    setState(() => _savingReminder = true);

    try {
      try {
        await _prefsRepository.saveWorkoutReminder(
          enabled: enabled,
          hour: prefs.hour,
          minute: prefs.minute,
        );
      } catch (error) {
        _showErrorSnackBar(
          'Could not save reminder settings: ${_errorMessage(error)}',
        );
        return;
      }

      try {
        if (enabled && prefs.hasTime) {
          await WorkoutReminderService.instance.scheduleDailyReminder(
            hour: prefs.hour!,
            minute: prefs.minute!,
          );
        } else {
          await WorkoutReminderService.instance.cancelReminder();
        }
      } catch (error) {
        _showErrorSnackBar(
          'Reminder settings saved, but notification scheduling failed: ${_errorMessage(error)}',
        );
        return;
      }
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  Future<void> _applyReminderResult(WorkoutTimePickerResult result) async {
    setState(() => _savingReminder = true);

    try {
      try {
        await _prefsRepository.saveWorkoutReminder(
          enabled: result.reminderEnabled,
          hour: result.hour,
          minute: result.minute,
        );
      } catch (error) {
        _showErrorSnackBar(
          'Could not save reminder settings: ${_errorMessage(error)}',
        );
        return;
      }

      try {
        if (result.reminderEnabled && result.hasTime) {
          await WorkoutReminderService.instance.scheduleDailyReminder(
            hour: result.hour!,
            minute: result.minute!,
          );
        } else {
          await WorkoutReminderService.instance.cancelReminder();
        }
      } catch (error) {
        _showErrorSnackBar(
          'Reminder time saved, but notification scheduling failed: ${_errorMessage(error)}',
        );
        return;
      }
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,

      appBar: AppBar(title: const Text('Workout Plan'), centerTitle: true),

      body: SafeArea(
        child: StreamBuilder<WorkoutPlan?>(
          stream: _repository.watchCurrentPlan(),

          builder:
              (BuildContext context, AsyncSnapshot<WorkoutPlan?> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final WorkoutPlan? plan = snapshot.data;

                return StreamBuilder<WorkoutReminderPrefs>(
                  stream: _prefsRepository.watchWorkoutReminder(),

                  builder:
                      (
                        BuildContext context,

                        AsyncSnapshot<WorkoutReminderPrefs> prefsSnapshot,
                      ) {
                        final WorkoutReminderPrefs prefs =
                            prefsSnapshot.data ?? const WorkoutReminderPrefs();

                        if (plan == null) {
                          return _EmptyPlanState(
                            onCreatePlan: () => _openCreatePlan(context),

                            showAiHelp: !_aiPromptDismissed,

                            onDismissAiHelp: () =>
                                setState(() => _aiPromptDismissed = true),

                            onGetAiHelp: () => _openAiChat(context),

                            reminderPrefs: prefs,

                            savingReminder: _savingReminder,

                            onEditReminder: () => _editReminderTime(prefs),

                            onToggleReminder: (bool v) =>
                                _toggleReminder(v, prefs),
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),

                          children: [
                            _PlanHeader(plan: plan),

                            const SizedBox(height: 16),

                            _ReminderCard(
                              prefs: prefs,

                              saving: _savingReminder,

                              onTapTime: () => _editReminderTime(prefs),

                              onToggle: (bool v) => _toggleReminder(v, prefs),
                            ),

                            const SizedBox(height: 16),

                            if (plan.status == WorkoutPlanStatus.draft)
                              FilledButton.icon(
                                onPressed: _starting
                                    ? null
                                    : () => _startPlan(plan),

                                style: FilledButton.styleFrom(
                                  backgroundColor: _kPrimaryColor,
                                ),

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

                                label: Text(
                                  _starting ? 'Starting…' : 'Start plan',
                                ),
                              )
                            else
                              FilledButton.icon(
                                onPressed: () => _openProgress(context),

                                style: FilledButton.styleFrom(
                                  backgroundColor: _kPrimaryColor,
                                ),

                                icon: const Icon(Icons.insights_outlined),

                                label: const Text('Track progress'),
                              ),

                            const SizedBox(height: 20),

                            Text(
                              'Your days',

                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: _kTextColor,

                                    fontWeight: FontWeight.w700,
                                  ),
                            ),

                            const SizedBox(height: 12),

                            ...plan.days.map(
                              (PlanDay day) => _CondensedDayCard(day: day),
                            ),

                            if (!_aiPromptDismissed) ...[
                              const SizedBox(height: 20),

                              _AiHelpCard(
                                onGetHelp: () => _openAiChat(context),

                                onDismiss: () =>
                                    setState(() => _aiPromptDismissed = true),
                              ),
                            ],
                          ],
                        );
                      },
                );
              },
        ),
      ),
    );
  }
}

extension on WorkoutReminderPrefs {
  WorkoutReminderPrefs copyWithEnabled({required bool enabled}) {
    return WorkoutReminderPrefs(enabled: enabled, hour: hour, minute: minute);
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.prefs,

    required this.saving,

    required this.onTapTime,

    required this.onToggle,
  });

  final WorkoutReminderPrefs prefs;

  final bool saving;

  final VoidCallback onTapTime;

  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final String timeLabel = prefs.enabled && prefs.hasTime
        ? prefs.formatTime()
        : 'Not set';

    return Material(
      color: _kCardColor,

      borderRadius: BorderRadius.circular(20),

      child: InkWell(
        onTap: saving ? null : onTapTime,

        borderRadius: BorderRadius.circular(20),

        child: Padding(
          padding: const EdgeInsets.all(18),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'Daily workout time',

                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,

                  color: _kTextColor,
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.schedule, color: _kPrimaryColor, size: 22),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      timeLabel,

                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _withOpacity(_kTextColor, 0.85),
                      ),
                    ),
                  ),

                  const Icon(Icons.chevron_right),
                ],
              ),

              const Divider(height: 24),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,

                title: const Text('Remind me'),

                value: prefs.enabled,

                onChanged: saving ? null : onToggle,

                activeThumbColor: _kPrimaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan});

  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final String statusLabel = switch (plan.status) {
      WorkoutPlanStatus.draft => 'Draft',

      WorkoutPlanStatus.active => 'Active',

      WorkoutPlanStatus.completed => 'Completed',
    };

    final Color chipColor = switch (plan.status) {
      WorkoutPlanStatus.draft => _kSecondaryColor,

      WorkoutPlanStatus.active => _kPrimaryColor,

      WorkoutPlanStatus.completed => Colors.grey,
    };

    return Material(
      color: _kCardColor,

      borderRadius: BorderRadius.circular(20),

      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Expanded(
                  child: Text(
                    plan.title,

                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _kTextColor,

                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Chip(
                  label: Text(statusLabel),

                  labelStyle: const TextStyle(
                    color: Colors.white,

                    fontWeight: FontWeight.w600,

                    fontSize: 12,
                  ),

                  backgroundColor: chipColor,

                  padding: EdgeInsets.zero,

                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            if (plan.progress.totalDays > 0) ...[
              const SizedBox(height: 8),

              Text(
                '${plan.progress.completedDays}/${plan.progress.totalDays} days completed',

                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _withOpacity(_kTextColor, 0.72),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CondensedDayCard extends StatelessWidget {
  const _CondensedDayCard({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      decoration: BoxDecoration(
        color: _kCardColor,

        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: _withOpacity(Colors.black, 0.04),

            blurRadius: 12,

            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.all(14),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              day.label,

              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _kTextColor,

                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            ...day.exercises.map(
              (PlanExercise exercise) => Padding(
                padding: const EdgeInsets.only(bottom: 4),

                child: Row(
                  children: [
                    Icon(
                      Icons.circle,

                      size: 6,

                      color: _withOpacity(_kPrimaryColor, 0.6),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        exercise.title,

                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _withOpacity(_kTextColor, 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiHelpCard extends StatelessWidget {
  const _AiHelpCard({required this.onGetHelp, required this.onDismiss});

  final VoidCallback onGetHelp;

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: _withOpacity(_kSecondaryColor, 0.12),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: _withOpacity(_kSecondaryColor, 0.35)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, color: _kSecondaryColor),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'Need help with your plan?',

                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,

                    color: _kTextColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'AI can explain or help you adjust your workout plan.',

            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _withOpacity(_kTextColor, 0.85),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onGetHelp,

                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                  ),

                  child: const Text('Get AI help'),
                ),
              ),

              const SizedBox(width: 10),

              TextButton(onPressed: onDismiss, child: const Text("I'm good")),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPlanState extends StatelessWidget {
  const _EmptyPlanState({
    required this.onCreatePlan,

    required this.showAiHelp,

    required this.onDismissAiHelp,

    required this.onGetAiHelp,

    required this.reminderPrefs,

    required this.savingReminder,

    required this.onEditReminder,

    required this.onToggleReminder,
  });

  final VoidCallback onCreatePlan;

  final bool showAiHelp;

  final VoidCallback onDismissAiHelp;

  final VoidCallback onGetAiHelp;

  final WorkoutReminderPrefs reminderPrefs;

  final bool savingReminder;

  final VoidCallback onEditReminder;

  final ValueChanged<bool> onToggleReminder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),

      children: [
        Center(
          child: Column(
            children: [
              Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade400),

              const SizedBox(height: 16),

              Text(
                "You don't have a workout plan yet.",

                textAlign: TextAlign.center,

                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _kTextColor,

                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Create a plan with AI or pick exercises from our tutorial library.',

                textAlign: TextAlign.center,

                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _withOpacity(_kTextColor, 0.72),
                ),
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: onCreatePlan,

                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimaryColor,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,

                    vertical: 14,
                  ),
                ),

                icon: const Icon(Icons.add_rounded),

                label: const Text('Create a plan'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _ReminderCard(
          prefs: reminderPrefs,

          saving: savingReminder,

          onTapTime: onEditReminder,

          onToggle: onToggleReminder,
        ),

        if (showAiHelp) ...[
          const SizedBox(height: 24),

          _AiHelpCard(onGetHelp: onGetAiHelp, onDismiss: onDismissAiHelp),
        ],
      ],
    );
  }
}
