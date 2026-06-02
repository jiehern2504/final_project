import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'analysis/pose_feedback.dart';
import 'analysis/pushup_analyzer.dart';
import 'analysis/squat_analyzer.dart';
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

  final PushUpRepCounter _pushUpReps = PushUpRepCounter();
  final SquatRepCounter _squatReps = SquatRepCounter();

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
        // YUV_420_888 avoids some NV21 ImageReader + preview black-screen paths on real devices.
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _mlKit = PoseMlKitController();
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        await _mlKit?.dispose();
        return;
      }

      // Assign before [startImageStream]: first frames can arrive before its
      // Future completes; [_onCameraImage] uses [_camera] and would drop them.
      _camera = controller;
      if (!mounted) {
        await controller.dispose();
        await _mlKit?.dispose();
        return;
      }

      try {
        await controller.startImageStream(_onCameraImage);
      } catch (e) {
        try {
          await controller.dispose();
        } catch (_) {}
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
      setState(() {
        _initializing = false;
      });
    } catch (e) {
      try {
        await controller?.dispose();
      } catch (_) {}
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
        _pushUpReps.clearPhase();
        _squatReps.clearPhase();
      } else {
        final Pose pose = poses.first;
        next = widget.exercise == PoseExerciseType.squat
            ? analyzeSquat(pose)
            : analyzePushUp(pose);
        if (widget.exercise == PoseExerciseType.squat) {
          _squatReps.update(pose);
        } else {
          _pushUpReps.update(pose);
        }
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

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  Future<void> _stopCamera() async {
    final CameraController? cam = _camera;
    _camera = null;
    if (cam != null) {
      if (cam.value.isStreamingImages) {
        await cam.stopImageStream();
      }
      await cam.dispose();
    }
    await _mlKit?.dispose();
    _mlKit = null;
  }

  int get _repDisplayCount => widget.exercise == PoseExerciseType.squat
      ? _squatReps.count
      : _pushUpReps.count;

  Color get _accentColor => widget.exercise == PoseExerciseType.squat
      ? const Color(0xffDF5089)
      : const Color(0xff005F9C);

  @override
  Widget build(BuildContext context) {
    final String title = widget.exercise == PoseExerciseType.squat
        ? 'Squat'
        : 'Push-up';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: ColoredBox(
        color: Colors.black,
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
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
        child: Text(
          'Camera unavailable.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final String exerciseTitle = widget.exercise == PoseExerciseType.squat
        ? 'Squat'
        : 'Push-up';

    return Stack(
      fit: StackFit.expand,
      children: [
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
          top: 16,
          left: 16,
          right: 16,
          child: _ExerciseTitleChip(
            title: exerciseTitle,
            icon: widget.exercise == PoseExerciseType.squat
                ? Icons.directions_walk
                : Icons.fitness_center,
            color: _accentColor,
          ),
        ),
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Center(
            child: _RepCountBadge(count: _repDisplayCount, color: _accentColor),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 24,
          child: _FeedbackBanner(feedback: _feedback),
        ),
      ],
    );
  }
}

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
          children: [
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
  const _RepCountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
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
          children: [
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
