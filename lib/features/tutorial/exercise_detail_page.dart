import 'dart:async';

import 'package:flutter/material.dart';

import '../pose/pose_camera_page.dart';
import '../pose/pose_exercise_type.dart';
import 'exercise_catalog.dart';
import 'exercise_video_error_panel.dart';
import 'exercise_video_player.dart';
import 'exercise_video_repository.dart';
import 'exercise_video_shimmer.dart';

class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({
    super.key,
    required this.exercise,
    required this.primaryColor,
    this.videoRepository,
  });

  final TutorialExercise exercise;
  final Color primaryColor;
  final ExerciseVideoRepository? videoRepository;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  late final ExerciseVideoRepository _repository;

  // Gate that lets the SIDE video start only after the FRONT one has settled,
  // so the two players don't contend for decoders/bandwidth on load.
  final ValueNotifier<bool> _sideActive = ValueNotifier<bool>(false);
  Timer? _sideFallbackTimer;

  @override
  void initState() {
    super.initState();
    _repository = widget.videoRepository ?? ExerciseVideoRepository();
    // Safety net: start SIDE anyway if FRONT never settles (e.g. slow network).
    _sideFallbackTimer = Timer(const Duration(seconds: 6), _openSideGate);
  }

  void _openSideGate() {
    if (!_sideActive.value) _sideActive.value = true;
  }

  @override
  void dispose() {
    _sideFallbackTimer?.cancel();
    _sideActive.dispose();
    super.dispose();
  }

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
                    storagePath: exercise.frontStoragePath,
                    repository: _repository,
                    clipTopRadius: true,
                    onSettled: _openSideGate,
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _sideActive,
                    builder: (context, active, _) {
                      return _AngleVideoSlot(
                        label: ExerciseVideoAngle.side.label,
                        storagePath: exercise.sideStoragePath,
                        repository: _repository,
                        muted: true,
                        active: active,
                      );
                    },
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

class _AngleVideoSlot extends StatefulWidget {
  const _AngleVideoSlot({
    required this.label,
    required this.storagePath,
    required this.repository,
    this.muted = false,
    this.clipTopRadius = false,
    this.active = true,
    this.onSettled,
  });

  final String label;
  final String storagePath;
  final ExerciseVideoRepository repository;
  final bool muted;
  final bool clipTopRadius;
  final bool active;
  final VoidCallback? onSettled;

  @override
  State<_AngleVideoSlot> createState() => _AngleVideoSlotState();
}

class _AngleVideoSlotState extends State<_AngleVideoSlot> {
  late Future<String> _urlFuture;
  int _retryGeneration = 0;

  @override
  void initState() {
    super.initState();
    _urlFuture = widget.repository.getDownloadUrl(widget.storagePath);
  }

  void _retry() {
    setState(() {
      _retryGeneration++;
      _urlFuture = widget.repository.getDownloadUrl(
        widget.storagePath,
        forceRefresh: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<String>(
              key: ValueKey('${widget.storagePath}-$_retryGeneration'),
              future: _urlFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ExerciseVideoShimmer(
                    height: height,
                    clipTopRadius: widget.clipTopRadius,
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  final exception = snapshot.error is ExerciseVideoException
                      ? snapshot.error! as ExerciseVideoException
                      : null;
                  return ExerciseVideoErrorPanel(
                    height: height,
                    exception: exception,
                    clipTopRadius: widget.clipTopRadius,
                    onRetry: _retry,
                  );
                }

                return ExerciseVideoPlayer(
                  key: ValueKey(
                    'player-${widget.storagePath}-$_retryGeneration',
                  ),
                  videoUrl: snapshot.data!,
                  detailStyle: true,
                  height: height,
                  muted: widget.muted,
                  clipTopRadius: widget.clipTopRadius,
                  active: widget.active,
                  onSettled: widget.onSettled,
                  onPlaybackFailed: _retry,
                );
              },
            ),
            Positioned(
              top: 8,
              left: 12,
              child: Text(
                widget.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          blurRadius: 4,
                          color: Color(0x99000000),
                        ),
                      ],
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
