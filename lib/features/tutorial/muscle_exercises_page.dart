import 'dart:async';

import 'package:flutter/material.dart';

import 'exercise_catalog.dart';
import 'exercise_detail_page.dart';
import 'exercise_video_error_panel.dart';
import 'exercise_video_player.dart';
import 'exercise_video_repository.dart';
import 'exercise_video_shimmer.dart';
import 'muscle_models.dart';

class MuscleExercisesPage extends StatefulWidget {
  const MuscleExercisesPage({
    super.key,
    required this.muscle,
    required this.primaryColor,
    this.videoRepository,
  });

  final MuscleId muscle;
  final Color primaryColor;
  final ExerciseVideoRepository? videoRepository;

  @override
  State<MuscleExercisesPage> createState() => _MuscleExercisesPageState();
}

class _MuscleExercisesPageState extends State<MuscleExercisesPage> {
  late final ExerciseVideoRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.videoRepository ?? ExerciseVideoRepository();
  }

  void _openDetail(TutorialExercise exercise) {
    unawaited(_repository.getDownloadUrl(exercise.sideStoragePath));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseDetailPage(
          exercise: exercise,
          primaryColor: widget.primaryColor,
          videoRepository: _repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = exercisesForMuscle(widget.muscle);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.muscle.label} Exercises'),
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
              primaryColor: widget.primaryColor,
              repository: _repository,
              onTap: () => _openDetail(exercise),
            );
          },
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.primaryColor,
    required this.repository,
    required this.onTap,
  });

  final TutorialExercise exercise;
  final Color primaryColor;
  final ExerciseVideoRepository repository;
  final VoidCallback onTap;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  static const double _previewHeight = 170;

  late Future<String> _urlFuture;
  int _retryGeneration = 0;
  bool _warmScheduled = false;

  @override
  void initState() {
    super.initState();
    _urlFuture =
        widget.repository.getDownloadUrl(widget.exercise.frontStoragePath);
  }

  void _retry() {
    setState(() {
      _retryGeneration++;
      _warmScheduled = false;
      _urlFuture = widget.repository.getDownloadUrl(
        widget.exercise.frontStoragePath,
        forceRefresh: true,
      );
    });
  }

  void _scheduleWarmup() {
    if (_warmScheduled) return;
    _warmScheduled = true;
    unawaited(
      widget.repository.warmController(widget.exercise.frontStoragePath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: widget.onTap,
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
              FutureBuilder<String>(
                key: ValueKey(
                  '${widget.exercise.frontStoragePath}-$_retryGeneration',
                ),
                future: _urlFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ExerciseVideoShimmer(
                      height: _previewHeight,
                      clipTopRadius: true,
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    final exception =
                        snapshot.error is ExerciseVideoException
                            ? snapshot.error! as ExerciseVideoException
                            : null;
                    return ExerciseVideoErrorPanel(
                      height: _previewHeight,
                      exception: exception,
                      clipTopRadius: true,
                      onRetry: _retry,
                    );
                  }
                  _scheduleWarmup();
                  return ExerciseVideoPlayer(
                    key: ValueKey(
                      'player-${widget.exercise.frontStoragePath}-'
                      '$_retryGeneration',
                    ),
                    videoUrl: snapshot.data!,
                    previewMode: true,
                    onPlaybackFailed: _retry,
                  );
                },
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
                        color: widget.primaryColor.withValues(alpha: 0.12),
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
                            widget.exercise.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(widget.exercise.subtitle),
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
