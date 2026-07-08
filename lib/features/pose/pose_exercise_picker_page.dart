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
              // TODO: replace with Image.asset('assets/glute_bridge.gif', ...)
              icon: Image.asset('assets/glute-bridge-exercise.gif', fit: BoxFit.cover),
              onTap: () => _open(context, PoseExerciseType.gluteBridge),
            ),
            const SizedBox(height: 14),

            // ── Plank ──────────────────────────────────────────────────────
            _ExerciseCard(
              title: 'Plank',
              subtitle: 'Body line · hold time (seconds)',
              color: _plankColor,
              // TODO: replace with Image.asset('assets/plank.gif', ...)
              icon: Image.asset('assets/plank.gif', fit: BoxFit.cover),
              onTap: () => _open(context, PoseExerciseType.plank),
            ),
            const SizedBox(height: 14),

            // ── Crunch ─────────────────────────────────────────────────────
            _ExerciseCard(
              title: 'Crunch',
              subtitle: 'Shoulder curl · hip angle · reps',
              color: _crunchColor,
              // TODO: replace with Image.asset('assets/crunch.gif', ...)
              icon: _PlaceholderIcon(
                icon: Icons.airline_seat_recline_extra,
                label: 'Add crunch.gif',
              ),
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

// ── Placeholder widget shown until a real GIF is added ────────────────────

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 9),
          ),
        ],
      ),
    );
  }
}