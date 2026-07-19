import 'package:flutter/material.dart';

import 'recommended_video.dart';

class VideoThumbnail extends StatelessWidget {
  const VideoThumbnail({
    super.key,
    required this.video,
    this.borderRadius = 12,
  });

  final RecommendedVideo video;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              video.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                  const ColoredBox(color: Color(0xFF141414)),
              loadingBuilder:
                  (BuildContext c, Widget child, ImageChunkEvent? progress) =>
                      progress == null
                      ? child
                      : const ColoredBox(color: Color(0xFF141414)),
            ),
            Center(
              child: Container(
                width: 46,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  video.duration,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
