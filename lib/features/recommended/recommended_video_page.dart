import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'recommended_video.dart';
import 'video_thumbnail.dart';

const Color _kPrimary = Color(0xFF4CAF50);
const Color _kText = Color(0xFF333333);

/// In-app YouTube player page. Plays [initial] in an embedded player and lists
/// the other videos under "Up next" — tapping one loads it in the same player
/// (like the YouTube app).
class RecommendedVideoPage extends StatefulWidget {
  const RecommendedVideoPage({super.key, required this.initial});

  final RecommendedVideo initial;

  @override
  State<RecommendedVideoPage> createState() => _RecommendedVideoPageState();
}

class _RecommendedVideoPageState extends State<RecommendedVideoPage> {
  late final YoutubePlayerController _controller;
  late RecommendedVideo _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    _controller = YoutubePlayerController.fromVideoId(
      videoId: _current.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  void _playVideo(RecommendedVideo video) {
    setState(() => _current = video);
    _controller.loadVideoById(videoId: video.videoId);
  }

  /// Opens the video in the YouTube app / browser. Needed for videos whose
  /// owner disabled embedded playback (error 150/152).
  Future<void> _openOnYouTube() async {
    final Uri url =
        Uri.parse('https://www.youtube.com/watch?v=${_current.videoId}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final List<RecommendedVideo> upNext = kRecommendedVideos
        .where((RecommendedVideo v) => v.id != _current.id)
        .toList();

    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (BuildContext context, Widget player) {
        return Scaffold(
          backgroundColor: const Color(0xFFF9FBF9),
          appBar: AppBar(title: const Text('Now playing'), centerTitle: true),
          body: SafeArea(
            child: Column(
              children: [
                player,
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    children: [
                      Text(
                        _current.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: _kText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _kPrimary.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person,
                                color: _kPrimary, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_current.channel} · recommended',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openOnYouTube,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open in YouTube'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF0000),
                            side: const BorderSide(color: Color(0xFFFF0000)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Follow along with the trainer. Warm up first, then move '
                        'through each exercise at your own pace.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF555555),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Up next',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _kText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ...upNext.map(
                        (RecommendedVideo v) => _UpNextTile(
                          video: v,
                          onTap: () => _playVideo(v),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UpNextTile extends StatelessWidget {
  const _UpNextTile({required this.video, required this.onTap});

  final RecommendedVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: VideoThumbnail(video: video, borderRadius: 10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kText,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.channel} · ${video.duration}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
