enum PoseFeedbackKind { good, adjust }

class PoseFeedback {
  const PoseFeedback({
    required this.kind,
    required this.headlineEn,
    required this.hintEn,
    required this.hintZh,
  });

  final PoseFeedbackKind kind;
  final String headlineEn;
  final String hintEn;
  final String hintZh;

  static const PoseFeedback noBody = PoseFeedback(
    kind: PoseFeedbackKind.adjust,
    headlineEn: 'Adjust',
    hintEn: 'Step into the frame so your full body is visible.',
    hintZh: '请入镜，确保全身在画面中。',
  );
}
