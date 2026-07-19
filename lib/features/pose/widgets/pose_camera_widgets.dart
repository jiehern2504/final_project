part of '../pose_camera_page.dart';

class _ExerciseTitleChip extends StatelessWidget {
  const _ExerciseTitleChip({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepCountBadge extends StatelessWidget {
  const _RepCountBadge({
    required this.count,
    required this.color,
    required this.isTimed,
  });

  final int count;
  final Color color;

  final bool isTimed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: isTimed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  's',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            )
          : Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.feedback});

  final PoseFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    switch (feedback.kind) {
      case PoseFeedbackKind.good:
        bg = Colors.green.shade700;
      case PoseFeedbackKind.almost:
        bg = Colors.amber.shade800;
      case PoseFeedbackKind.adjust:
        bg = Colors.red.shade700;
    }
    return Material(
      color: bg.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              feedback.headlineEn,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              feedback.hintEn,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
