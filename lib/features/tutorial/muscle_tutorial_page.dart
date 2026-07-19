import 'package:flutter/material.dart';

import 'body_map.dart';
import 'muscle_exercises_page.dart';
import 'muscle_models.dart';
import '../../core/theme/app_colors.dart';

class MuscleTutorialPage extends StatefulWidget {
  const MuscleTutorialPage({super.key});

  static const Color primaryColor = AppColors.primary;

  @override
  State<MuscleTutorialPage> createState() => _MuscleTutorialPageState();
}

class _MuscleTutorialPageState extends State<MuscleTutorialPage> {
  BodySide _side = BodySide.front;
  MuscleId? _selected;

  void _toggleSide(BodySide next) {
    if (_side == next) return;
    setState(() => _side = next);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = MuscleTutorialPage.primaryColor;
    final bool hasSelection = _selected != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Muscle Tutorial"), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Muscle Group',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _SideToggle(
                    value: _side,
                    primaryColor: primary,
                    onChanged: _toggleSide,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeOut,
                    child: AspectRatio(
                      key: ValueKey<BodySide>(_side),
                      aspectRatio: 3 / 5,
                      child: BodyMap(
                        side: _side,
                        primaryColor: primary,
                        selected: _selected,
                        onSelected: (MuscleId? m) =>
                            setState(() => _selected = m),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SelectedMuscleCard(muscle: _selected, primaryColor: primary),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: hasSelection
                      ? () {
                          final MuscleId muscle = _selected!;
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  MuscleExercisesPage(
                                    muscle: muscle,
                                    primaryColor: primary,
                                  ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primary.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View Exercises',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideToggle extends StatelessWidget {
  const _SideToggle({
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  final BodySide value;
  final Color primaryColor;
  final ValueChanged<BodySide> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            selected: value == BodySide.front,
            label: 'Front',
            primaryColor: primaryColor,
            onTap: () => onChanged(BodySide.front),
          ),
          const SizedBox(width: 6),
          _ToggleChip(
            selected: value == BodySide.back,
            label: 'Back',
            primaryColor: primaryColor,
            onTap: () => onChanged(BodySide.back),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.selected,
    required this.label,
    required this.primaryColor,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = selected ? primaryColor : Colors.transparent;
    final Color fg = selected ? Colors.white : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SelectedMuscleCard extends StatelessWidget {
  const _SelectedMuscleCard({required this.muscle, required this.primaryColor});

  final MuscleId? muscle;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final String label = muscle?.label ?? 'Tap a muscle to select';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              muscle == null
                  ? Icons.touch_app_rounded
                  : Icons.check_circle_rounded,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected muscle',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
