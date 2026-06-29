import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose_constants.dart';
import '../pose_geometry.dart';
import 'pose_feedback.dart';

bool _usable(PoseLandmark? l) =>
    l != null && l.likelihood >= kMinLandmarkLikelihood;

/// Key angles for a plank hold.
class PlankMetrics {
  const PlankMetrics({
    required this.bodyAngleDeg,
    required this.elbowAngleDeg,
  });

  /// Shoulder–hip–ankle angle. Should stay close to 180° (flat body line).
  final double bodyAngleDeg;

  /// Shoulder–elbow–wrist angle. Forearm plank ≈ 90°; high plank ≈ 160–180°.
  final double elbowAngleDeg;
}

/// Picks the side with better landmark confidence.
PlankMetrics? computePlankMetrics(Pose pose) {
  final PlankMetrics? left = _metricsForSide(
    pose: pose,
    shoulderT: PoseLandmarkType.leftShoulder,
    elbowT:    PoseLandmarkType.leftElbow,
    wristT:    PoseLandmarkType.leftWrist,
    hipT:      PoseLandmarkType.leftHip,
    ankleT:    PoseLandmarkType.leftAnkle,
  );
  final PlankMetrics? right = _metricsForSide(
    pose: pose,
    shoulderT: PoseLandmarkType.rightShoulder,
    elbowT:    PoseLandmarkType.rightElbow,
    wristT:    PoseLandmarkType.rightWrist,
    hipT:      PoseLandmarkType.rightHip,
    ankleT:    PoseLandmarkType.rightAnkle,
  );

  if (left == null && right == null) return null;
  if (left == null) return right;
  if (right == null) return left;

  final double ls = _sideConfidence(pose, isLeft: true);
  final double rs = _sideConfidence(pose, isLeft: false);
  return ls >= rs ? left : right;
}

PlankMetrics? _metricsForSide({
  required Pose pose,
  required PoseLandmarkType shoulderT,
  required PoseLandmarkType elbowT,
  required PoseLandmarkType wristT,
  required PoseLandmarkType hipT,
  required PoseLandmarkType ankleT,
}) {
  final PoseLandmark? shoulder = pose.landmarks[shoulderT];
  final PoseLandmark? elbow    = pose.landmarks[elbowT];
  final PoseLandmark? wrist    = pose.landmarks[wristT];
  final PoseLandmark? hip      = pose.landmarks[hipT];
  final PoseLandmark? ankle    = pose.landmarks[ankleT];

  if (!_usable(shoulder) || !_usable(elbow) || !_usable(wrist) ||
      !_usable(hip) || !_usable(ankle)) {
    return null;
  }

  final double bodyAngle  = angleAtPoseLandmarks(shoulder!, hip!, ankle!);
  final double elbowAngle = angleAtPoseLandmarks(shoulder, elbow!, wrist!);

  return PlankMetrics(bodyAngleDeg: bodyAngle, elbowAngleDeg: elbowAngle);
}

double _sideConfidence(Pose pose, {required bool isLeft}) {
  final PoseLandmark? s = pose.landmarks[isLeft
      ? PoseLandmarkType.leftShoulder
      : PoseLandmarkType.rightShoulder];
  final PoseLandmark? h = pose.landmarks[isLeft
      ? PoseLandmarkType.leftHip
      : PoseLandmarkType.rightHip];
  final PoseLandmark? a = pose.landmarks[isLeft
      ? PoseLandmarkType.leftAnkle
      : PoseLandmarkType.rightAnkle];
  if (s == null || h == null || a == null) return 0;
  return (s.likelihood + h.likelihood + a.likelihood) / 3;
}

/// Returns [PoseFeedback] for a plank hold.
///
/// Plank is a timed exercise — this only evaluates FORM, not reps.
/// The rep counter for plank accumulates seconds held in good form.
PoseFeedback analyzePlank(Pose pose) {
  final PlankMetrics? m = computePlankMetrics(pose);
  if (m == null) return PoseFeedback.noBody;

  final double dev = (m.bodyAngleDeg - 180).abs();

  if (dev > (180 - kPlankBodyMinDeg)) {
    final bool hipsHigh = m.bodyAngleDeg > 180;
    return PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: hipsHigh
          ? 'Lower your hips — keep a straight line from shoulders to ankles.'
          : 'Lift your hips — don\'t let them sag toward the floor.',
      hintZh: hipsHigh
          ? '臀部下降，肩到脚踝保持一条直线。'
          : '抬起臀部，不要塌腰。',
    );
  }

  return const PoseFeedback(
    kind: PoseFeedbackKind.good,
    headlineEn: 'Good',
    hintEn: 'Solid plank — breathe and hold.',
    hintZh: '保持良好，正常呼吸，继续坚持。',
  );
}