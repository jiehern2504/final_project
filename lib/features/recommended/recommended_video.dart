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

    final Match? m = RegExp(
      r'(?:v=|/embed/|youtu\.be/|/shorts/)([A-Za-z0-9_-]{11})',
    ).firstMatch(raw);
    if (m != null) return m.group(1)!;
    return raw;
  }

  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}

const List<RecommendedVideo> kRecommendedVideos = <RecommendedVideo>[
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=uep2HH5MW7k',
    title: '5 MIN STANDING FULL BODY WORKOUT (No Jumping )',
    channel: 'Shirlyn Kim',
    duration: '5:23',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=_6-k5-w1bZw',
    title: '5 MIN WARM UP',
    channel: 'TIFFxDAN',
    duration: '6:19',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=LoXHHD43jPM',
    title: '5MIN FLAT STOMACH WORKOUT',
    channel: 'evas pilates',
    duration: '5:20',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=kWodISSgIqI',
    title: '5 MIN ABS WORKOUT',
    channel: 'TIFFxDAN',
    duration: '5:30',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=MqcB6g4RzeA',
    title: 'Flat Stomach & Tiny Waist in 10 Mins',
    channel: 'Isla Rune Pilates',
    duration: '11:00',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=kj6F7H68PW4',
    title: '10 MIN FULL BODY BEGINNER WORKOUT',
    channel: 'Rowan Row',
    duration: '11:25',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=2pLT-olgUJs',
    title: 'Get Abs in 2 WEEKS | Abs Workout Challenge',
    channel: 'Chloe Ting',
    duration: '11:03',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=Tz9d7By2ytQ',
    title: 'NO GYM FULL BODY WORKOUT (feat. 5 min Tabata)',
    channel: 'Allblanc TV',
    duration: '5:23',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=I9nG-G4B5Bs',
    title: 'Lower Body Workout | Toned Legs & Butt',
    channel: 'Chloe Ting',
    duration: '13:01',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=0OfLE2lBS4I',
    title: '5 MIN DAILY INTENSE SIX PACK ABS (100% Results)',
    channel: 'Rowan Row',
    duration: '6:19',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=j64BBgBGNIU',
    title: '10 Mins Toned Arms Workout | No Equipment',
    channel: 'Chloe Ting',
    duration: '10:57',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=fyKm4UHZ9tk',
    title: '5 MIN LEG WORKOUT - Butt, Thighs & Calves ',
    channel: 'Patrik Rajcsanyi',
    duration: '5:10',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=uNILu4KSHQM',
    title: '10 MIN SITTING ARM & SHOULDER WORKOUT',
    channel: 'Emi Wong',
    duration: '10:50',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=xf58Smi1kt4',
    title: '5 MIN UPPER BODY WORKOUT',
    channel: 'Patrik Rajcsanyi',
    duration: '5:11',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=riS89biXH7E&t=12s',
    title: 'FIX & SLIM YOUR BACK + BETTER POSTURE in 10 minutes',
    channel: 'Emi Wong',
    duration: '10:55',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=841gJUczmzg',
    title: 'Killer LEG Workout at Home (No Equipment)',
    channel: 'NEXT Workout',
    duration: '8:06',
  ),
  RecommendedVideo(
    id: 'https://www.youtube.com/watch?v=XYp7GQicd0c',
    title:
        '10min Slim Arm Workout |🔥 Burn Flabby Arm Fat | All Seated & No Equipment',
    channel: 'hailey C.',
    duration: '10:29',
  ),
];
