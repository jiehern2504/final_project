import 'package:url_launcher/url_launcher.dart';

import 'recommended_video.dart';

/// Opens [video] in the YouTube app (or browser). This is the reliable way to
/// play the content — in-app WebView embedding is blocked by YouTube on many
/// devices (error 152), so we hand off to YouTube itself.
Future<void> openRecommendedVideo(RecommendedVideo video) async {
  final Uri url =
      Uri.parse('https://www.youtube.com/watch?v=${video.videoId}');
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
