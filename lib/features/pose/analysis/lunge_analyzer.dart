import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose_constants.dart';
import '../pose_geometry.dart';
import 'pose_feedback.dart';

bool _usable(PoseLandmark? l) =>
    l != null && l.likelihood >= kMinLandmarkLikelihood;

/// Key angles captured during a lunge.
class LungeMetrics {
  const LungeMetrics({
    required this.frontKneeAngleDeg,
    required this.torsoLeanFromVerticalDeg,
  });

  /// Hip–knee–ankle angle of the leading (front) leg.
  final double frontKneeAngleDeg;

  /// Torso tilt from vertical (shoulder–hip vector vs upward axis).
  final double torsoLeanFromVerticalDeg;
}

/// Tries to extract [LungeMetrics] from [pose] by picking the side whose
/// front knee is MORE bent (i.e. the leading leg).
LungeMetrics? computeLungeMetrics(Pose pose) {
  final LungeMetrics? left = _metricsForSide(
    pose: pose,
    hipT: PoseLandmarkType.leftHip,
    kneeT: PoseLandmarkType.leftKnee,
    ankleT: PoseLandmarkType.leftAnkle,
    shoulderT: PoseLandmarkType.leftShoulder,
  );
  final LungeMetrics? right = _metricsForSide(
    pose: pose,
    hipT: PoseLandmarkType.rightHip,
    kneeT: PoseLandmarkType.rightKnee,
    ankleT: PoseLandmarkType.rightAnkle,
    shoulderT: PoseLandmarkType.rightShoulder,
  );

  if (left == null && right == null) return null;
  if (left == null) return right;
  if (right == null) return left;

  // Pick the side with the smaller (more bent) knee angle = the front leg.
  return left.frontKneeAngleDeg <= right.frontKneeAngleDeg ? left : right;
}

LungeMetrics? _metricsForSide({
  required Pose pose,
  required PoseLandmarkType hipT,
  required PoseLandmarkType kneeT,
  required PoseLandmarkType ankleT,
  required PoseLandmarkType shoulderT,
}) {
  final PoseLandmark? hip      = pose.landmarks[hipT];
  final PoseLandmark? knee     = pose.landmarks[kneeT];
  final PoseLandmark? ankle    = pose.landmarks[ankleT];
  final PoseLandmark? shoulder = pose.landmarks[shoulderT];

  if (!_usable(hip) || !_usable(knee) || !_usable(ankle) || !_usable(shoulder)) {
    return null;
  }

  final double kneeAngle = angleAtPoseLandmarks(hip!, knee!, ankle!);

  // Torso lean: angle between shoulder→hip vector and upward vertical.
  final double dx = shoulder!.x - hip.x;
  final double dy = shoulder.y - hip.y;          // y increases downward in image coords
  // Convert to angle from vertical (0° = perfectly upright).
  final double torsoLean = (dy.abs() < 1e-9)
      ? 0
      : (dx / dy).abs() * 57.2957795; // approx atan in degrees for small angles

  return LungeMetrics(
    frontKneeAngleDeg: kneeAngle,
    torsoLeanFromVerticalDeg: torsoLean,
  );
}

/// Returns [PoseFeedback] describing lunge form.
PoseFeedback analyzeLunge(Pose pose) {
  final LungeMetrics? m = computeLungeMetrics(pose);
  if (m == null) return PoseFeedback.noBody;

  if (m.frontKneeAngleDeg > kLungeFrontKneeTooHighDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: 'Step deeper — bend your front knee closer to 90°.',
      hintZh: '弓步再深一点，前膝弯曲接近90°。',
    );
  }

  if (m.torsoLeanFromVerticalDeg > kLungeMaxTorsoLeanDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: 'Keep your torso upright — don\'t lean too far forward.',
      hintZh: '上身保持直立，不要过度前倾。',
    );
  }

  if (m.frontKneeAngleDeg <= kLungeFrontKneeGoodMaxDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.good,
      headlineEn: 'Good',
      hintEn: 'Great depth — keep your front knee above your ankle.',
      hintZh: '深度不错！保持前膝在脚踝正上方。',
    );
  }

  return const PoseFeedback(
    kind: PoseFeedbackKind.good,
    headlineEn: 'Good',
    hintEn: 'Nice lunge position.',
    hintZh: '姿势良好。',
  );
}