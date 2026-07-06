import 'package:flutter/material.dart';

import 'exercise_catalog.dart';
import 'exercise_detail_page.dart';
import 'exercise_video_player.dart';
import 'muscle_models.dart';

class MuscleExercisesPage extends StatelessWidget {
  const MuscleExercisesPage({
    super.key,
    required this.muscle,
    required this.primaryColor,
  });

  final MuscleId muscle;
  final Color primaryColor;

  void _openDetail(BuildContext context, TutorialExercise exercise) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseDetailPage(
          exercise: exercise,
          primaryColor: primaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = exercisesForMuscle(muscle);
    return Scaffold(
      appBar: AppBar(
        title: Text('${muscle.label} Exercises'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: exercises.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int index) {
            final exercise = exercises[index];
            return _ExerciseCard(
              exercise: exercise,
              primaryColor: primaryColor,
              onTap: () => _openDetail(context, exercise),
            );
          },
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.primaryColor,
    required this.onTap,
  });

  final TutorialExercise exercise;
  final Color primaryColor;
  final VoidCallback onTap;

  static const double _previewHeight = 170;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExerciseVideoPlayer(
                key: ValueKey('player-${exercise.id}'),
                videoUrl: 'assets/tutorial_videos/${exercise.id}_front.mp4',
                previewMode: true,
                height: _previewHeight,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: primaryColor,
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
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
