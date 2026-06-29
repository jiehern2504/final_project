import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'analysis/pose_feedback.dart';
import 'analysis/pushup_analyzer.dart';
import 'analysis/squat_analyzer.dart';
import 'analysis/lunge_analyzer.dart';
import 'analysis/glutebridge_analyzer.dart';
import 'analysis/plank_analyzer.dart';
import 'analysis/crunch_analyzer.dart';
import 'input_image_from_camera.dart'
    show inputImageFromCameraImage, mlKitRotationForCameraFrame;
import 'pose_constants.dart';
import 'pose_exercise_type.dart';
import 'pose_mlkit_controller.dart';
import 'pose_painter.dart';
import 'rep_counter.dart';

class PoseCameraPage extends StatefulWidget {
  const PoseCameraPage({super.key, required this.exercise});

  final PoseExerciseType exercise;

  @override
  State<PoseCameraPage> createState() => _PoseCameraPageState();
}

class _PoseCameraPageState extends State<PoseCameraPage> {
  CameraController? _camera;
  PoseMlKitController? _mlKit;
  bool _initializing = true;
  String? _error;
  PoseFeedback _feedback = PoseFeedback.noBody;
  PoseFeedback _pendingFeedback = PoseFeedback.noBody;
  DateTime? _lastUiUpdate;
  int _frameIndex = 0;
  bool _processing = false;

  List<Pose> _lastPoses = <Pose>[];
  Size _inputImageSize = Size.zero;
  InputImageRotation _lastRotation = InputImageRotation.rotation0deg;

  // ── Rep / hold counters ────────────────────────────────────────────────────
  final PushUpRepCounter      _pushUpReps      = PushUpRepCounter();
  final SquatRepCounter       _squatReps       = SquatRepCounter();
  final LungeRepCounter       _lungeReps       = LungeRepCounter();
  final GluteBridgeRepCounter _gluteBridgeReps = GluteBridgeRepCounter();
  final PlankHoldTimer        _plankTimer      = PlankHoldTimer();
  final CrunchRepCounter      _crunchReps      = CrunchRepCounter();

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    if (!Platform.isAndroid) {
      setState(() {
        _initializing = false;
        _error = 'Pose detection is implemented for Android in this build.';
      });
      return;
    }

    final PermissionStatus status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _initializing = false;
        _error =
        'Camera permission is required for live pose feedback. You can enable it in system settings.';
      });
      return;
    }

    CameraController? controller;
    try {
      final List<CameraDescription> cameras = await availableCameras();
      final CameraDescription camera = cameras.firstWhere(
            (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _mlKit = PoseMlKitController();
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        await _mlKit?.dispose();
        return;
      }

      _camera = controller;
      if (!mounted) {
        await controller.dispose();
        await _mlKit?.dispose();
        return;
      }

      try {
        await controller.startImageStream(_onCameraImage);
      } catch (e) {
        try { await controller.dispose(); } catch (_) {}
        await _mlKit?.dispose();
        _mlKit = null;
        _camera = null;
        if (mounted) {
          setState(() {
            _initializing = false;
            _error = 'Could not start the camera stream: $e';
          });
        }
        return;
      }

      if (!mounted) {
        await controller.dispose();
        await _mlKit?.dispose();
        return;
      }
      setState(() => _initializing = false);
    } catch (e) {
      try { await controller?.dispose(); } catch (_) {}
      await _mlKit?.dispose();
      _mlKit = null;
      _camera = null;
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Could not start the camera: $e';
        });
      }
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    final CameraController? cam = _camera;
    final PoseMlKitController? ml = _mlKit;
    if (cam == null || ml == null || !cam.value.isInitialized) return;
    if (_processing) return;

    _frameIndex++;
    if (_frameIndex % kPoseProcessEveryNFrames != 0) return;

    final InputImage? input = inputImageFromCameraImage(
      image: image,
      controller: cam,
      camera: cam.description,
    );
    if (input == null) return;

    final InputImageRotation? rot = mlKitRotationForCameraFrame(
      controller: cam,
      camera: cam.description,
    );

    _processing = true;
    try {
      final List<Pose> poses = await ml.processImage(input);
      if (!mounted) return;

      final Size frameSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final PoseFeedback next;
      if (poses.isEmpty) {
        next = PoseFeedback.noBody;
        _clearAllPhases();
      } else {
        final Pose pose = poses.first;
        next = _analyze(pose);
        _updateCounter(pose);
      }

      _pendingFeedback = next;
      final DateTime now = DateTime.now();
      final bool allowBannerUi = _lastUiUpdate == null ||
          now.difference(_lastUiUpdate!) >= kPoseUiFeedbackThrottle;

      setState(() {
        _lastRotation = rot ?? _lastRotation;
        _lastPoses = poses;
        _inputImageSize = frameSize;
        if (allowBannerUi) {
          _feedback = _pendingFeedback;
          _lastUiUpdate = now;
        }
      });
    } finally {
      _processing = false;
    }
  }

  /// Dispatches to the correct analyzer for the selected exercise.
  PoseFeedback _analyze(Pose pose) {
    switch (widget.exercise) {
      case PoseExerciseType.squat:
        return analyzeSquat(pose);
      case PoseExerciseType.pushUp:
        return analyzePushUp(pose);
      case PoseExerciseType.lunge:
        return analyzeLunge(pose);
      case PoseExerciseType.gluteBridge:
        return analyzeGluteBridge(pose);
      case PoseExerciseType.plank:
        return analyzePlank(pose);
      case PoseExerciseType.crunch:
        return analyzeCrunch(pose);
    }
  }

  /// Updates only the counter for the active exercise.
  void _updateCounter(Pose pose) {
    switch (widget.exercise) {
      case PoseExerciseType.squat:
        _squatReps.update(pose);
      case PoseExerciseType.pushUp:
        _pushUpReps.update(pose);
      case PoseExerciseType.lunge:
        _lungeReps.update(pose);
      case PoseExerciseType.gluteBridge:
        _gluteBridgeReps.update(pose);
      case PoseExerciseType.plank:
        _plankTimer.update(pose);
      case PoseExerciseType.crunch:
        _crunchReps.update(pose);
    }
  }

  void _clearAllPhases() {
    _pushUpReps.clearPhase();
    _squatReps.clearPhase();
    _lungeReps.clearPhase();
    _gluteBridgeReps.clearPhase();
    _plankTimer.clearPhase();
    _crunchReps.clearPhase();
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  Future<void> _stopCamera() async {
    final CameraController? cam = _camera;
    _camera = null;
    if (cam != null) {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
      await cam.dispose();
    }
    await _mlKit?.dispose();
    _mlKit = null;
  }

  // ── Display helpers ────────────────────────────────────────────────────────

  /// Returns the rep count OR held seconds for display in the badge.
  int get _displayCount {
    switch (widget.exercise) {
      case PoseExerciseType.squat:       return _squatReps.count;
      case PoseExerciseType.pushUp:      return _pushUpReps.count;
      case PoseExerciseType.lunge:       return _lungeReps.count;
      case PoseExerciseType.gluteBridge: return _gluteBridgeReps.count;
      case PoseExerciseType.plank:       return _plankTimer.seconds;
      case PoseExerciseType.crunch:      return _crunchReps.count;
    }
  }

  /// True for plank — badge shows "s" suffix instead of "reps".
  bool get _isTimed => widget.exercise == PoseExerciseType.plank;

  String get _exerciseTitle {
    switch (widget.exercise) {
      case PoseExerciseType.squat:       return 'Squat';
      case PoseExerciseType.pushUp:      return 'Push-up';
      case PoseExerciseType.lunge:       return 'Lunge';
      case PoseExerciseType.gluteBridge: return 'Glute Bridge';
      case PoseExerciseType.plank:       return 'Plank';
      case PoseExerciseType.crunch:      return 'Crunch';
    }
  }

  IconData get _exerciseIcon {
    switch (widget.exercise) {
      case PoseExerciseType.squat:       return Icons.directions_walk;
      case PoseExerciseType.pushUp:      return Icons.fitness_center;
      case PoseExerciseType.lunge:       return Icons.transfer_within_a_station;
      case PoseExerciseType.gluteBridge: return Icons.airline_seat_flat;
      case PoseExerciseType.plank:       return Icons.horizontal_rule;
      case PoseExerciseType.crunch:      return Icons.airline_seat_recline_extra;
    }
  }

  Color get _accentColor {
    switch (widget.exercise) {
      case PoseExerciseType.squat:       return const Color(0xffDF5089);
      case PoseExerciseType.pushUp:      return const Color(0xff005F9C);
      case PoseExerciseType.lunge:       return const Color(0xff7B3FA0);
      case PoseExerciseType.gluteBridge: return const Color(0xffC0622C);
      case PoseExerciseType.plank:       return const Color(0xff1A7A5E);
      case PoseExerciseType.crunch:      return const Color(0xff9C6B00);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_exerciseTitle), centerTitle: true),
      body: ColoredBox(color: Colors.black, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }
    final CameraController? cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      return const Center(
        child: Text('Camera unavailable.', style: TextStyle(color: Colors.white70)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Center(
          child: CameraPreview(
            cam,
            child: Positioned.fill(
              child: CustomPaint(
                painter: PosePainter(
                  imageSize: _inputImageSize,
                  poses: _lastPoses,
                  rotation: _lastRotation,
                  lensDirection: cam.description.lensDirection,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16, left: 16, right: 16,
          child: _ExerciseTitleChip(
            title: _exerciseTitle,
            icon: _exerciseIcon,
            color: _accentColor,
          ),
        ),
        Positioned(
          bottom: 120, left: 0, right: 0,
          child: Center(
            child: _RepCountBadge(
              count: _displayCount,
              color: _accentColor,
              isTimed: _isTimed,
            ),
          ),
        ),
        Positioned(
          left: 12, right: 12, bottom: 24,
          child: _FeedbackBanner(feedback: _feedback),
        ),
      ],
    );
  }
}

// ── Sub-widgets (unchanged style from original) ────────────────────────────

class _ExerciseTitleChip extends StatelessWidget {
  const _ExerciseTitleChip({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepCountBadge extends StatelessWidget {
  const _RepCountBadge({
    required this.count,
    required this.color,
    required this.isTimed,
  });

  final int count;
  final Color color;

  /// When true, appends "s" (seconds) instead of showing a bare number.
  final bool isTimed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: isTimed
          ? Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            's',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      )
          : Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.feedback});

  final PoseFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final bool good = feedback.kind == PoseFeedbackKind.good;
    final Color bg = good ? Colors.green.shade800 : Colors.orange.shade900;
    return Material(
      color: bg.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              feedback.headlineEn,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              feedback.hintEn,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              feedback.hintZh,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}