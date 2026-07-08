/// A recommended workout video hosted on YouTube.
///
/// [id] is the YouTube video id — the part after `watch?v=` or `youtu.be/`
/// (e.g. `https://youtu.be/dQw4w9WgXcQ` → `dQw4w9WgXcQ`). Swap the placeholder
/// entries in [kRecommendedVideos] for real workout videos.
class RecommendedVideo {
  const RecommendedVideo({
    required this.id,
    required this.title,
    required this.channel,
    required this.duration,
  });

  final String id;
  final String title;
  final String channel;
  final String duration;

  /// The bare YouTube video id. [id] may be pasted as a FULL URL
  /// (`watch?v=…`, `youtu.be/…`, `shorts/…`, `embed/…`) or already be a bare
  /// id — this normalises it either way, so you can just paste the link.
  String get videoId {
    final String raw = id.trim();
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(raw)) return raw;
    final Uri? uri = Uri.tryParse(raw);
    if (uri != null) {
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      final String? v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments.first == 'shorts' ||
              uri.pathSegments.first == 'embed')) {
        return uri.pathSegments[1];
      }
    }
    // Last resort: pull the id out of any string (even a full <iframe> embed).
    final Match? m = RegExp(
      r'(?:v=|/embed/|youtu\.be/|/shorts/)([A-Za-z0-9_-]{11})',
    ).firstMatch(raw);
    if (m != null) return m.group(1)!;
    return raw;
  }

  /// YouTube-provided thumbnail image for this video.
  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}

/// PLACEHOLDER list. These ids point to stable public videos so the thumbnails
/// and playback work while testing — replace them with real workout videos.
const List<RecommendedVideo> kRecommendedVideos = <RecommendedVideo>[
  // TEMP embed test — a video known to ALLOW embedding. Delete this entry once
  // you've confirmed in-app playback works.
  RecommendedVideo(
    id: 'aqz-KE-bpKQ',
    title: 'Embed test — should play in-app',
    channel: 'Blender',
    duration: '10:34',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=uep2HH5MW7k',
    title: '10 min full body workout',
    channel: 'FitChannel',
    duration: '10:24',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=TKGqKSnyMo4',
    title: 'Beginner leg day · no equipment',
    channel: 'HomeFit',
    duration: '12:04',
  ),
  RecommendedVideo(
    id: 'kJQP7kiw5Fk',
    title: '5 min ab blast',
    channel: 'CoreDaily',
    duration: '5:11',
  ),
  RecommendedVideo(
    id: '3JZ_D3ELwOQ',
    title: 'Full body stretch and cooldown',
    channel: 'MoveWell',
    duration: '8:47',
  ),
];
