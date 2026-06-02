import 'package:flutter/material.dart';

const Color _kPrimaryColor = Color(0xFF4CAF50);

class WorkoutTimePickerResult {
  const WorkoutTimePickerResult({
    required this.reminderEnabled,
    this.hour,
    this.minute,
  });

  final bool reminderEnabled;
  final int? hour;
  final int? minute;

  bool get hasTime => hour != null && minute != null;
}

/// Shared sheet: pick daily workout time and toggle reminders.
Future<WorkoutTimePickerResult?> showWorkoutTimePickerSheet(
  BuildContext context, {
  bool initialReminderEnabled = true,
  TimeOfDay? initialTime,
  bool requireTimeWhenEnabled = false,
}) {
  return showModalBottomSheet<WorkoutTimePickerResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) => _WorkoutTimePickerSheet(
      initialReminderEnabled: initialReminderEnabled,
      initialTime: initialTime,
      requireTimeWhenEnabled: requireTimeWhenEnabled,
    ),
  );
}

class _WorkoutTimePickerSheet extends StatefulWidget {
  const _WorkoutTimePickerSheet({
    required this.initialReminderEnabled,
    this.initialTime,
    required this.requireTimeWhenEnabled,
  });

  final bool initialReminderEnabled;
  final TimeOfDay? initialTime;
  final bool requireTimeWhenEnabled;

  @override
  State<_WorkoutTimePickerSheet> createState() =>
      _WorkoutTimePickerSheetState();
}

class _WorkoutTimePickerSheetState extends State<_WorkoutTimePickerSheet> {
  late bool _reminderEnabled;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _reminderEnabled = widget.initialReminderEnabled;
    _selectedTime = widget.initialTime;
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 18, minute: 30),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _kPrimaryColor,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _save() {
    if (_reminderEnabled &&
        widget.requireTimeWhenEnabled &&
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a workout time or turn off reminders.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      WorkoutTimePickerResult(
        reminderEnabled: _reminderEnabled,
        hour: _selectedTime?.hour,
        minute: _selectedTime?.minute,
      ),
    );
  }

  String _timeLabel() {
    if (_selectedTime == null) return 'Not set';
    final TimeOfDay t = _selectedTime!;
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    return loc.formatTimeOfDay(t);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Daily workout time',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'When do you usually work out? We can send a daily reminder.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Send daily reminder'),
            value: _reminderEnabled,
            activeThumbColor: _kPrimaryColor,
            onChanged: (bool value) => setState(() => _reminderEnabled = value),
          ),
          if (_reminderEnabled) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, color: _kPrimaryColor),
              title: const Text('Workout time'),
              subtitle: Text(_timeLabel()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTime,
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
