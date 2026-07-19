enum PoseFeedbackKind { good, adjust, almost }

class PoseFeedback {
  const PoseFeedback({
    required this.kind,
    required this.headlineEn,
    required this.hintEn,
  });

  final PoseFeedbackKind kind;
  final String headlineEn;
  final String hintEn;

  static const PoseFeedback noBody = PoseFeedback(
    kind: PoseFeedbackKind.adjust,
    headlineEn: 'Adjust',
    hintEn: 'Step into the frame so your full body is visible.',
  );
}
