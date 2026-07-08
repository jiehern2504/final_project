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
    this.autoPlay = true,
    this.forcePaused = false,
    this.onPlayingChanged,
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

  /// When false the video does NOT auto-start: it shows a play button and the
  /// controller is created lazily on the first tap. This keeps two videos from
  /// decoding at the same time (which froze one of them on some devices).
  final bool autoPlay;

  /// When a parent sets this true, the video pauses. Used to enforce that only
  /// one of several videos plays at a time.
  final bool forcePaused;

  /// Notifies the parent when THIS video starts (true) or is paused by the user
  /// (false), so the parent can coordinate mutual-exclusion between videos.
  final ValueChanged<bool>? onPlayingChanged;

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
    if (widget.active && widget.autoPlay) _initController();
  }

  @override
  void didUpdateWidget(ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _playbackFailedNotified = false;
      _settledNotified = false;
      _autoRetried = false;
      if (widget.active && widget.autoPlay) _initController();
    } else if (!oldWidget.active &&
        widget.active &&
        widget.autoPlay &&
        _controller == null) {
      // Gate opened — start now.
      _initController();
    }

    // Parent asked us to pause (another video took over).
    if (widget.forcePaused && !oldWidget.forcePaused) {
      final c = _controller;
      if (c != null && c.value.isInitialized && c.value.isPlaying) {
        c.pause();
      }
    }
  }

  /// Tap handler for tap-to-play (autoPlay == false).
  void _togglePlay() {
    final controller = _controller;
    if (controller == null) {
      // First tap → create the controller, initialise and play.
      _playbackFailedNotified = false;
      _autoRetried = false;
      _initController();
      widget.onPlayingChanged?.call(true);
      return;
    }
    if (!_initialized) return; // still loading
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        widget.onPlayingChanged?.call(false);
      } else {
        controller.play();
        widget.onPlayingChanged?.call(true);
      }
    });
  }

  void _initController() {
    _controller = VideoPlayerController.asset(widget.videoUrl)
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
    final controller = _controller;
    final bool ready = controller != null && _initialized;

    // Base content: the video if ready, a dark placeholder if not started yet
    // (tap-to-play), otherwise the loading shimmer.
    final Widget content;
    if (ready) {
      final Widget video = AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      );
      content = widget._coverMode
          ? _CoverVideoFrame(
              height: widget.height,
              video: video,
              controllerSize: controller.value.size,
              clipTop: _clipTop,
              showPlayOverlay: widget.previewMode,
            )
          : AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: video,
            );
    } else if (!widget.autoPlay && _controller == null) {
      content = _PlaceholderBox(height: widget.height, clipTop: _clipTop);
    } else {
      content = ExerciseVideoShimmer(
        height: widget.height,
        clipTopRadius: _clipTop,
      );
    }

    // Auto-play mode: no tap controls.
    if (widget.autoPlay) return content;

    // Tap-to-play mode: show a play button when not playing, and toggle on tap.
    final bool showPlayButton =
        _controller == null || (ready && !controller.value.isPlaying);
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          content,
          if (showPlayButton) ...[
            Container(color: Colors.black.withValues(alpha: 0.30)),
            const Icon(
              Icons.play_circle_fill_rounded,
              size: 56,
              color: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}

/// Plain dark box shown before a tap-to-play video is started (no decoder yet).
class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox({required this.height, required this.clipTop});

  final double height;
  final bool clipTop;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: clipTop
          ? const BorderRadius.vertical(top: Radius.circular(16))
          : BorderRadius.zero,
      child: Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFF1E1E1E),
      ),
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
