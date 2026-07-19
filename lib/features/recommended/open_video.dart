import 'package:url_launcher/url_launcher.dart';

import 'recommended_video.dart';

Future<void> openRecommendedVideo(RecommendedVideo video) async {
  final Uri url = Uri.parse('https://www.youtube.com/watch?v=${video.videoId}');
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
