import 'package:flutter/material.dart';

import 'pose_camera_page.dart';
import 'pose_exercise_type.dart';

/// Picker page — styled after the original two-card design.
/// Each card shows the exercise name, key metrics tracked, and either a GIF
/// or a fallback icon placeholder (replace the Icon widget with Image.asset
/// once you have the GIF files).
class PoseExercisePickerPage extends StatelessWidget {
  const PoseExercisePickerPage({super.key});

  // ── Accent colours (one per exercise) ─────────────────────────────────────
  static const Color _squatColor       = Color(0xFFDF5089);
  static const Color _pushUpColor      = Color(0xFF005F9C);
  static const Color _gluteBridgeColor = Color(0xFFC0622C);
  static const Color _plankColor       = Color(0xFF1A7A5E);
  static const Color _crunchColor      = Color(0xFF9C6B00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Pose Detection'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            Text(
              'Choose an exercise',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFE59400), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'For accurate detection, stand sideways to the camera so '
                      'your full body is visible from the side.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF7A5B00),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'On-device pose estimation with live feedback, '
                  'skeleton overlay and rep / hold counts.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            // ── Squat ──────────────────────────────────────────────────────
            _ExerciseCard(
              title: 'Squat',
              subtitle: 'Knee angle · torso alignment · reps',
              color: _squatColor,
              // Replace with: Image.asset('assets/squat.gif', fit: BoxFit.cover)
              icon: Image.asset('assets/squat.gif', fit: BoxFit.cover),
              onTap: () => _open(context, PoseExerciseType.squat),
            ),
            const SizedBox(height: 14),

            // ── Push-up ────────────────────────────────────────────────────
            _ExerciseCard(
              title: 'Push-up',
              subtitle: 'Elbow angle · body line · reps',
              color: _pushUpColor,
              icon: Image.asset('assets/pushup.gif', fit: BoxFit.cover),
              onTap: () => _open(context, PoseExerciseType.pushUp),
            ),
            const SizedBox(height: 14),

            // ── Glute Bridge ───────────────────────────────────────────────
            _ExerciseCard(
              title: 'Glute Bridge',
              subtitle: 'Hip height · knee angle · reps',
              color: _gluteBridgeColor,
              icon: Image.asset('assets/glute-bridge-exercise.gif', fit: BoxFit.cover),
              onTap: () => _open(context, PoseExerciseType.gluteBridge),
            ),
            const SizedBox(height: 14),

            // ── Plank ──────────────────────────────────────────────────────
            _ExerciseCard(
              title: 'Plank',
              subtitle: 'Body line · hold time (seconds)',
              color: _plankColor,
              icon: Image.asset('assets/plank.gif', fit: BoxFit.cover),
              onTap: () => _open(context, PoseExerciseType.plank),
            ),
            const SizedBox(height: 14),

            // ── Crunch ─────────────────────────────────────────────────────
            _ExerciseCard(
              title: 'Crunch',
              subtitle: 'Shoulder curl · hip angle · reps',
              color: _crunchColor,
                icon: Image.asset('assets/crunch.gif', fit: BoxFit.cover),
              onTap: () => _open(context, PoseExerciseType.crunch),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, PoseExerciseType type) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PoseCameraPage(exercise: type),
      ),
    );
  }
}

// ── Exercise card (unchanged from original) ────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 132,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                // Left — text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right — GIF or placeholder
                SizedBox(
                  width: 94,
                  height: 74,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: icon,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

