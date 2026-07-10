/// Feedback state shown to the user during live detection:
/// - [adjust]: form needs correcting (red).
/// - [almost]: form is fine and the movement is in progress, but the rep has
///   NOT been counted yet (yellow).
/// - [good]: a rep was just counted / a plank second is being held (green).
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
