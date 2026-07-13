import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'analysis/pose_feedback.dart';
import 'analysis/pushup_analyzer.dart';
import 'analysis/squat_analyzer.dart';
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

part 'widgets/pose_camera_widgets.dart';

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
  // Keeps the green "Good! Rep counted" banner on screen briefly after a rep.
  DateTime? _repFlashUntil;
  int _frameIndex = 0;
  bool _processing = false;

  List<Pose> _lastPoses = <Pose>[];
  Size _inputImageSize = Size.zero;
  InputImageRotation _lastRotation = InputImageRotation.rotation0deg;

  // ── Rep / hold counters ────────────────────────────────────────────────────
  final PushUpRepCounter      _pushUpReps      = PushUpRepCounter();
  final SquatRepCounter       _squatReps       = SquatRepCounter();
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
      if (cameras.isEmpty) {
        throw StateError('No camera found on this device.');
      }
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
      bool justCounted = false;
      if (poses.isEmpty) {
        next = PoseFeedback.noBody;
        _clearAllPhases();
      } else {
        final Pose pose = poses.first;
        final PoseFeedback formFeedback = _analyze(pose);
        justCounted = _updateCounter(pose);
        next = _deriveFeedback(formFeedback, justCounted);
      }

      _pendingFeedback = next;
      final DateTime now = DateTime.now();
      // Force an immediate banner update on a counted rep so the green flash
      // isn't swallowed by the throttle.
      final bool allowBannerUi = justCounted ||
          _lastUiUpdate == null ||
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
      case PoseExerciseType.gluteBridge:
        return analyzeGluteBridge(pose);
      case PoseExerciseType.plank:
        return analyzePlank(pose);
      case PoseExerciseType.crunch:
        return analyzeCrunch(pose);
    }
  }

  /// Updates the counter for the active exercise. Returns true when a rep was
  /// just counted this frame (for timed plank, when the second count changed).
  bool _updateCounter(Pose pose) {
    switch (widget.exercise) {
      case PoseExerciseType.squat:
        return _squatReps.update(pose);
      case PoseExerciseType.pushUp:
        return _pushUpReps.update(pose);
      case PoseExerciseType.gluteBridge:
        return _gluteBridgeReps.update(pose);
      case PoseExerciseType.plank:
        return _plankTimer.update(pose);
      case PoseExerciseType.crunch:
        return _crunchReps.update(pose);
    }
  }

  /// Combines the analyzer's form judgement with the rep counter into the
  /// three-state feedback shown to the user:
  /// - adjust (red): the analyzer found a form problem.
  /// - almost (yellow): form is fine but the rep hasn't been counted yet.
  /// - good (green): a rep was just counted (or, for plank, form is being held).
  PoseFeedback _deriveFeedback(PoseFeedback form, bool justCounted) {
    // Plank is a timed hold: good form = green (accumulating), else adjust.
    if (_isTimed) {
      if (form.kind == PoseFeedbackKind.adjust) return form;
      return const PoseFeedback(
        kind: PoseFeedbackKind.good,
        headlineEn: 'Holding',
        hintEn: 'Nice — keep your body in a straight line.',
      );
    }

    final DateTime now = DateTime.now();
    if (justCounted) {
      _repFlashUntil = now.add(const Duration(milliseconds: 900));
    }

    // Green flash has TOP priority: the instant a rep is counted, show green —
    // even though the body (standing back up) may momentarily look like a form
    // the analyzer would otherwise flag as "adjust". This keeps the green in
    // sync with the count instead of lagging behind it.
    if (_repFlashUntil != null && now.isBefore(_repFlashUntil!)) {
      return const PoseFeedback(
        kind: PoseFeedbackKind.good,
        headlineEn: 'Good!',
        hintEn: 'Rep counted — keep going.',
      );
    }

    // Form problem → show the specific correction in red.
    if (form.kind == PoseFeedbackKind.adjust) return form;

    // Form is fine but no rep has registered yet → yellow.
    return const PoseFeedback(
      kind: PoseFeedbackKind.almost,
      headlineEn: 'Almost',
      hintEn: 'Good form — finish the full movement to count a rep.',
    );
  }

  void _clearAllPhases() {
    _pushUpReps.clearPhase();
    _squatReps.clearPhase();
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
      case PoseExerciseType.gluteBridge: return 'Glute Bridge';
      case PoseExerciseType.plank:       return 'Plank';
      case PoseExerciseType.crunch:      return 'Crunch';
    }
  }

  IconData get _exerciseIcon {
    switch (widget.exercise) {
      case PoseExerciseType.squat:       return Icons.directions_walk;
      case PoseExerciseType.pushUp:      return Icons.fitness_center;
      case PoseExerciseType.gluteBridge: return Icons.airline_seat_flat;
      case PoseExerciseType.plank:       return Icons.horizontal_rule;
      case PoseExerciseType.crunch:      return Icons.airline_seat_recline_extra;
    }
  }

  Color get _accentColor {
    switch (widget.exercise) {
      case PoseExerciseType.squat:       return const Color(0xffDF5089);
      case PoseExerciseType.pushUp:      return const Color(0xff005F9C);
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

