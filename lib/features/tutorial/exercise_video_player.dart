import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'exercise_video_shimmer.dart';

class ExerciseVideoPlayer extends StatefulWidget {
  const ExerciseVideoPlayer({
    super.key,
    required this.videoUrl,
    this.previewMode = false,
    this.detailStyle = false,
    this.muted = false,
    this.clipTopRadius = false,
    this.height = 170,
    this.onPlaybackFailed,
    this.active = true,
    this.onSettled,
  });

  final String videoUrl;
  final bool previewMode;
  final bool detailStyle;
  final bool muted;
  final bool clipTopRadius;
  final double height;
  final VoidCallback? onPlaybackFailed;

  /// When false, the controller is NOT created yet (a shimmer is shown). Used
  /// to stagger multiple players so they don't grab hardware decoders and
  /// network bandwidth at the exact same moment.
  final bool active;

  /// Fires once the player has "settled" — either it started playing or it
  /// failed. Lets a parent release a gate that was waiting on this player.
  final VoidCallback? onSettled;

  bool get _coverMode => previewMode || detailStyle;

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _playbackFailedNotified = false;
  bool _settledNotified = false;

  // Stall watchdog: if playback does not advance for a while, auto-retry once.
  Timer? _stallTimer;
  Duration _lastPosition = Duration.zero;
  int _stalledTicks = 0;
  bool _autoRetried = false;

  bool get _looping => widget.previewMode || widget.detailStyle;

  bool get _clipTop => widget.previewMode || widget.clipTopRadius;

  @override
  void initState() {
    super.initState();
    if (widget.active) _initController();
  }

  @override
  void didUpdateWidget(ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _playbackFailedNotified = false;
      _settledNotified = false;
      _autoRetried = false;
      if (widget.active) _initController();
    } else if (!oldWidget.active && widget.active && _controller == null) {
      // Gate opened — start now.
      _initController();
    }
  }

  void _initController() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(_looping)
      ..setVolume(widget.previewMode || widget.muted ? 0 : 1)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller!.play();
        _notifySettled();
        _startStallWatchdog();
      }).catchError((Object e) {
        _onInitError(e);
        return null;
      });
  }

  void _notifySettled() {
    if (_settledNotified) return;
    _settledNotified = true;
    widget.onSettled?.call();
  }

  /// Periodically checks that playback is advancing. If it stays stuck (stuck
  /// buffering / frozen frame) for a few seconds, retry once.
  void _startStallWatchdog() {
    _stallTimer?.cancel();
    _lastPosition = Duration.zero;
    _stalledTicks = 0;
    _stallTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final controller = _controller;
      if (!mounted || controller == null || !controller.value.isInitialized) {
        return;
      }
      // If it isn't meant to be playing (e.g. app backgrounded), don't treat
      // the frozen position as a stall.
      if (!controller.value.isPlaying) {
        _stalledTicks = 0;
        _lastPosition = controller.value.position;
        return;
      }
      final position = controller.value.position;
      final bool advanced = position != _lastPosition;
      _lastPosition = position;
      if (advanced) {
        _stalledTicks = 0;
        return;
      }
      // Should be playing but not advancing this tick.
      _stalledTicks++;
      if (_stalledTicks >= 2 && !_autoRetried) {
        // ~6s stuck → retry once via the parent's retry hook.
        _autoRetried = true;
        _stallTimer?.cancel();
        debugPrint('ExerciseVideo stalled, auto-retrying [${widget.videoUrl}]');
        _onInitError('stalled');
      }
    });
  }

  void _onInitError(Object e) {
    if (!mounted || _playbackFailedNotified) return;
    _playbackFailedNotified = true;
    debugPrint('ExerciseVideo playback [${widget.videoUrl}]: $e');
    _disposeController();
    _notifySettled();
    widget.onPlaybackFailed?.call();
  }

  void _disposeController() {
    _stallTimer?.cancel();
    _stallTimer = null;
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_playbackFailedNotified && widget.onPlaybackFailed != null) {
      return ExerciseVideoShimmer(
        height: widget.height,
        clipTopRadius: _clipTop,
      );
    }

    if (_controller == null || !_initialized) {
      return ExerciseVideoShimmer(
        height: widget.height,
        clipTopRadius: _clipTop,
      );
    }

    final controller = _controller!;
    final Widget video = AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );

    if (widget._coverMode) {
      return _CoverVideoFrame(
        height: widget.height,
        video: video,
        controllerSize: controller.value.size,
        clipTop: _clipTop,
        showPlayOverlay: widget.previewMode,
      );
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: video,
    );
  }
}

class _CoverVideoFrame extends StatelessWidget {
  const _CoverVideoFrame({
    required this.height,
    required this.video,
    required this.controllerSize,
    required this.clipTop,
    required this.showPlayOverlay,
  });

  final double height;
  final Widget video;
  final Size controllerSize;
  final bool clipTop;
  final bool showPlayOverlay;

  @override
  Widget build(BuildContext context) {
    final borderRadius = clipTop
        ? const BorderRadius.vertical(top: Radius.circular(16))
        : BorderRadius.zero;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controllerSize.width,
                height: controllerSize.height,
                child: video,
              ),
            ),
            if (showPlayOverlay) ...[
              Container(
                color: Colors.black.withValues(alpha: 0.15),
              ),
              Icon(
                Icons.play_circle_fill_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
