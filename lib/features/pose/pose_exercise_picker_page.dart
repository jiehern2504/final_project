import 'package:flutter/material.dart';

import 'pose_camera_page.dart';
import 'pose_exercise_type.dart';

/// Picker styled after `realtime_exercises` listing (colored cards).
class PoseExercisePickerPage extends StatelessWidget {
  const PoseExercisePickerPage({super.key});

  static const Color _squatColor = Color(0xFF4CAF50);
  static const Color _pushUpColor = Color(0xFFFFB74D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI pose detection'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Choose an exercise',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'On-device pose estimation with live feedback (proposal) '
                  'plus skeleton overlay and rep counts (reference apps).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            /// ✅ Squat (GIF)
            _ExerciseCard(
              title: 'Squat',
              subtitle: 'Knee angle, torso alignment, reps',
              color: _squatColor,
              icon: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/squat.gif',
                  fit: BoxFit.cover,
                ),
              ),
              onTap: () => _open(context, PoseExerciseType.squat),
            ),

            const SizedBox(height: 14),

            /// Push-up (GIF)
            _ExerciseCard(
              title: 'Push-up',
              subtitle: 'Elbow angle, body line, reps',
              color: _pushUpColor,
              icon: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/pushup.gif',
                  fit: BoxFit.cover,
                ),
              ),
              onTap: () => _open(context, PoseExerciseType.pushUp),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, PoseExerciseType type) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            PoseCameraPage(exercise: type),
      ),
    );
  }
}

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

  /// ✅ CHANGED: IconData ➜ Widget
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
              children: [
                /// LEFT TEXT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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

                /// RIGHT GIF / ICON
                SizedBox(
                  width: 94,
                  height: 74,
                  child: icon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}