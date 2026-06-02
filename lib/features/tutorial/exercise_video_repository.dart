import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class ExerciseVideoRepository {
  ExerciseVideoRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final Map<String, String> _urlCache = {};
  final Map<String, VideoPlayerController> _warmControllers = {};

  Future<String> getDownloadUrl(
    String storagePath, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _urlCache.remove(storagePath);
      final warm = _warmControllers.remove(storagePath);
      warm?.dispose();
    } else {
      final cached = _urlCache[storagePath];
      if (cached != null) return cached;
    }

    try {
      final url = await _storage.ref(storagePath).getDownloadURL();
      _urlCache[storagePath] = url;
      return url;
    } on FirebaseException catch (e) {
      debugPrint(
        'ExerciseVideo url [$storagePath]: ${e.code} ${e.message}',
      );
      throw ExerciseVideoException(
        storagePath: storagePath,
        message: e.message ?? 'Failed to load video',
        code: e.code,
      );
    } catch (e) {
      debugPrint('ExerciseVideo url [$storagePath]: $e');
      throw ExerciseVideoException(
        storagePath: storagePath,
        message: e.toString(),
      );
    }
  }

  void invalidate(String storagePath) {
    _urlCache.remove(storagePath);
    final warm = _warmControllers.remove(storagePath);
    warm?.dispose();
  }

  void clearCache() {
    _urlCache.clear();
    disposeWarmControllers();
  }

  /// Pre-initializes a player for [storagePath] while the list card is visible.
  Future<void> warmController(String storagePath) async {
    if (_warmControllers.containsKey(storagePath)) return;
    try {
      final url = await getDownloadUrl(storagePath);
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(url))
            ..setLooping(true)
            ..setVolume(0);
      await controller.initialize();
      _warmControllers[storagePath] = controller;
    } catch (_) {
      // Warmup is best-effort; detail page will load normally on failure.
    }
  }

  /// Returns a pre-initialized controller, if any, and removes it from the pool.
  VideoPlayerController? takeWarmController(String storagePath) {
    return _warmControllers.remove(storagePath);
  }

  void disposeWarmControllers() {
    for (final controller in _warmControllers.values) {
      controller.dispose();
    }
    _warmControllers.clear();
  }
}

class ExerciseVideoException implements Exception {
  ExerciseVideoException({
    required this.storagePath,
    required this.message,
    this.code,
  });

  final String storagePath;
  final String message;
  final String? code;

  @override
  String toString() => 'ExerciseVideoException($storagePath): $message';
}
