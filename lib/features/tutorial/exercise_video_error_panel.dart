import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'exercise_video_repository.dart';

/// Shared error UI for tutorial video URL load and playback failures.
class ExerciseVideoErrorPanel extends StatelessWidget {
  const ExerciseVideoErrorPanel({
    super.key,
    required this.height,
    this.onRetry,
    this.exception,
    this.message,
    this.clipTopRadius = false,
    this.showGoBack = false,
    this.isPlaybackFailure = false,
  });

  final double height;
  final VoidCallback? onRetry;
  final ExerciseVideoException? exception;
  final String? message;
  final bool clipTopRadius;
  final bool showGoBack;
  final bool isPlaybackFailure;

  bool get _showRetry {
    if (onRetry == null) return false;
    if (isPlaybackFailure) return true;
    final code = exception?.code;
    if (code == null) return true;
    switch (code) {
      case 'object-not-found':
      case 'unauthorized':
      case 'unauthenticated':
      case 'permission-denied':
        return false;
      default:
        return true;
    }
  }

  String get _subtitle {
    if (message != null) return message!;
    if (isPlaybackFailure) {
      return 'Video failed to play. Tap Retry to reload.';
    }
    final code = exception?.code;
    if (code == null) {
      return 'Check your connection and try again';
    }
    switch (code) {
      case 'unauthorized':
      case 'unauthenticated':
      case 'permission-denied':
        return 'Sign in to watch tutorial videos';
      case 'object-not-found':
        return "This video hasn't been uploaded yet";
      default:
        return 'Check your connection and try again';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && (exception != null || isPlaybackFailure)) {
      debugPrint(
        'ExerciseVideoErrorPanel: playback=$isPlaybackFailure '
        'code=${exception?.code} path=${exception?.storagePath}',
      );
    }

    final borderRadius = clipTopRadius
        ? const BorderRadius.vertical(top: Radius.circular(16))
        : BorderRadius.zero;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: borderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 10),
            Text(
              "Couldn't load video",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (_showRetry) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
            if (showGoBack) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
