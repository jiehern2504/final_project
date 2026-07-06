import 'package:flutter/material.dart';

import '../pose/pose_camera_page.dart';
import '../pose/pose_exercise_type.dart';
import 'exercise_catalog.dart';
import 'exercise_video_player.dart';

class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({
    super.key,
    required this.exercise,
    required this.primaryColor,
  });

  final TutorialExercise exercise;
  final Color primaryColor;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final hasCta = exercise.poseDetectType != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: Text(exercise.title),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Expanded(
                  child: _AngleVideoSlot(
                    label: ExerciseVideoAngle.front.label,
                    assetPath: 'assets/tutorial_videos/${exercise.id}_front.mp4',
                    clipTopRadius: true,
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _AngleVideoSlot(
                    label: ExerciseVideoAngle.side.label,
                    assetPath: 'assets/tutorial_videos/${exercise.id}_side.mp4',
                    muted: true,
                  ),
                ),
                Material(
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: widget.primaryColor
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.fitness_center_rounded,
                                color: widget.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exercise.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(exercise.subtitle),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasCta)
                        _AiDetectCta(poseType: exercise.poseDetectType!),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AngleVideoSlot extends StatelessWidget {
  const _AngleVideoSlot({
    required this.label,
    required this.assetPath,
    this.muted = false,
    this.clipTopRadius = false,
  });

  final String label;
  final String assetPath;
  final bool muted;
  final bool clipTopRadius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            ExerciseVideoPlayer(
              key: ValueKey('player-$assetPath'),
              videoUrl: assetPath,
              detailStyle: true,
              height: height,
              muted: muted,
              clipTopRadius: clipTopRadius,
            ),
            Positioned(
              top: 8,
              left: 12,
              child: Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 4, color: Color(0x99000000))],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AiDetectCta extends StatelessWidget {
  const _AiDetectCta({required this.poseType});

  final PoseExerciseType poseType;

  static const Color _accentGreen = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PoseCameraPage(exercise: poseType),
              ),
            );
          },
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Try AI pose detection'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _accentGreen,
            side: const BorderSide(color: _accentGreen),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}
