import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose_constants.dart';
import '../pose_geometry.dart';
import 'pose_feedback.dart';

/// Knee internal angle (hip–knee–ankle) and torso lean vs vertical (degrees).
class SquatMetrics {
  const SquatMetrics({
    required this.kneeAngleDeg,
    required this.torsoLeanFromVerticalDeg,
  });

  final double kneeAngleDeg;
  final double torsoLeanFromVerticalDeg;
}

double _angleFromVerticalDeg(Offset v) {
  const Offset up = Offset(0, -1);
  final double dot = (v.dx * up.dx + v.dy * up.dy) /
      (v.distance * up.distance + 1e-9);
  return math.acos(dot.clamp(-1.0, 1.0)) * 180 / math.pi;
}

bool _usable(PoseLandmark? l) =>
    l != null && l.likelihood >= kMinLandmarkLikelihood;

SquatMetrics? _metricsForSide({
  required Pose pose,
  required PoseLandmarkType hipT,
  required PoseLandmarkType kneeT,
  required PoseLandmarkType ankleT,
  required PoseLandmarkType shoulderT,
}) {
  final PoseLandmark? hip = pose.landmarks[hipT];
  final PoseLandmark? knee = pose.landmarks[kneeT];
  final PoseLandmark? ankle = pose.landmarks[ankleT];
  final PoseLandmark? shoulder = pose.landmarks[shoulderT];
  if (!_usable(hip) ||
      !_usable(knee) ||
      !_usable(ankle) ||
      !_usable(shoulder)) {
    return null;
  }
  final PoseLandmark h = hip!;
  final PoseLandmark k = knee!;
  final PoseLandmark a = ankle!;
  final PoseLandmark s = shoulder!;
  final double kneeAngle = angleAtPoseLandmarks(h, k, a);
  final Offset torso = Offset(s.x - h.x, s.y - h.y);
  final double lean = _angleFromVerticalDeg(torso);
  return SquatMetrics(kneeAngleDeg: kneeAngle, torsoLeanFromVerticalDeg: lean);
}

SquatMetrics? computeSquatMetrics(Pose pose) {
  final SquatMetrics? left = _metricsForSide(
    pose: pose,
    hipT: PoseLandmarkType.leftHip,
    kneeT: PoseLandmarkType.leftKnee,
    ankleT: PoseLandmarkType.leftAnkle,
    shoulderT: PoseLandmarkType.leftShoulder,
  );
  final SquatMetrics? right = _metricsForSide(
    pose: pose,
    hipT: PoseLandmarkType.rightHip,
    kneeT: PoseLandmarkType.rightKnee,
    ankleT: PoseLandmarkType.rightAnkle,
    shoulderT: PoseLandmarkType.rightShoulder,
  );
  if (left == null && right == null) return null;
  if (left == null) return right;
  if (right == null) return left;
  final double leftScore = _sideScore(pose, isLeft: true);
  final double rightScore = _sideScore(pose, isLeft: false);
  return leftScore >= rightScore ? left : right;
}

double _sideScore(Pose pose, {required bool isLeft}) {
  double minLike(double a, double b, double c) =>
      math.min(a, math.min(b, c));

  if (isLeft) {
    final PoseLandmark? h = pose.landmarks[PoseLandmarkType.leftHip];
    final PoseLandmark? k = pose.landmarks[PoseLandmarkType.leftKnee];
    final PoseLandmark? a = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (h == null || k == null || a == null) return 0;
    return minLike(h.likelihood, k.likelihood, a.likelihood);
  }
  final PoseLandmark? h = pose.landmarks[PoseLandmarkType.rightHip];
  final PoseLandmark? k = pose.landmarks[PoseLandmarkType.rightKnee];
  final PoseLandmark? a = pose.landmarks[PoseLandmarkType.rightAnkle];
  if (h == null || k == null || a == null) return 0;
  return minLike(h.likelihood, k.likelihood, a.likelihood);
}

PoseFeedback analyzeSquat(Pose pose) {
  final SquatMetrics? m = computeSquatMetrics(pose);
  if (m == null) {
    return PoseFeedback.noBody;
  }

  if (m.kneeAngleDeg > kSquatKneeAngleTooHighDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: 'Squat a bit lower — bend your knees more.',
      hintZh: '再蹲低一点，膝关节多弯曲一些。',
    );
  }

  if (m.torsoLeanFromVerticalDeg > kSquatMaxTorsoLeanFromVerticalDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: 'Keep your chest a little more upright.',
      hintZh: '躯干略前倾过多，尽量保持上身更直立。',
    );
  }

  if (m.kneeAngleDeg < kSquatKneeAngleGoodMinDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.good,
      headlineEn: 'Good',
      hintEn: 'Depth looks solid — stay controlled.',
      hintZh: '深度不错，注意保持稳定。',
    );
  }

  return const PoseFeedback(
    kind: PoseFeedbackKind.good,
    headlineEn: 'Good',
    hintEn: 'Nice squat position.',
    hintZh: '姿势良好。',
  );
}
