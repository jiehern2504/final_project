import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose_constants.dart';
import '../pose_geometry.dart';
import 'pose_feedback.dart';

bool _usable(PoseLandmark? l) =>
    l != null && l.likelihood >= kMinLandmarkLikelihood;

class PushUpMetrics {
  const PushUpMetrics({
    required this.elbowAngleDeg,
    required this.hipDeviationFromStraightDeg,
    required this.bodyAxisFromHorizontalDeg,
    required this.wristBelowShoulder,
  });

  final double elbowAngleDeg;
  final double hipDeviationFromStraightDeg;
  final double bodyAxisFromHorizontalDeg;
  final bool wristBelowShoulder;
}

PushUpMetrics? _metricsForSide({
  required Pose pose,
  required PoseLandmarkType shoulderT,
  required PoseLandmarkType elbowT,
  required PoseLandmarkType wristT,
  required PoseLandmarkType hipT,
  required PoseLandmarkType ankleT,
}) {
  final PoseLandmark? shoulder = pose.landmarks[shoulderT];
  final PoseLandmark? elbow = pose.landmarks[elbowT];
  final PoseLandmark? wrist = pose.landmarks[wristT];
  final PoseLandmark? hip = pose.landmarks[hipT];
  final PoseLandmark? ankle = pose.landmarks[ankleT];
  if (!_usable(shoulder) ||
      !_usable(elbow) ||
      !_usable(wrist) ||
      !_usable(hip) ||
      !_usable(ankle)) {
    return null;
  }
  final PoseLandmark sh = shoulder!;
  final PoseLandmark el = elbow!;
  final PoseLandmark wr = wrist!;
  final PoseLandmark hi = hip!;
  final PoseLandmark an = ankle!;
  final double elbowAngle = angleAtPoseLandmarks(sh, el, wr);
  final double hipAngle = angleAtPoseLandmarks(sh, hi, an);
  final double hipDev = (hipAngle - 180).abs();
  final double bodyAxisFromHorizontalDeg =
      math.atan2((an.y - sh.y).abs(), (an.x - sh.x).abs() + 1e-9) *
      180 /
      math.pi;
  return PushUpMetrics(
    elbowAngleDeg: elbowAngle,
    hipDeviationFromStraightDeg: hipDev,
    bodyAxisFromHorizontalDeg: bodyAxisFromHorizontalDeg,
    wristBelowShoulder: wr.y > sh.y,
  );
}

double _armSideScore(Pose pose, {required bool isLeft}) {
  final PoseLandmarkType s = isLeft
      ? PoseLandmarkType.leftShoulder
      : PoseLandmarkType.rightShoulder;
  final PoseLandmarkType e = isLeft
      ? PoseLandmarkType.leftElbow
      : PoseLandmarkType.rightElbow;
  final PoseLandmarkType w = isLeft
      ? PoseLandmarkType.leftWrist
      : PoseLandmarkType.rightWrist;
  final PoseLandmark? a = pose.landmarks[s];
  final PoseLandmark? b = pose.landmarks[e];
  final PoseLandmark? c = pose.landmarks[w];
  if (a == null || b == null || c == null) return 0;
  return math.min(a.likelihood, math.min(b.likelihood, c.likelihood));
}

PushUpMetrics? computePushUpMetrics(Pose pose) {
  final PushUpMetrics? left = _metricsForSide(
    pose: pose,
    shoulderT: PoseLandmarkType.leftShoulder,
    elbowT: PoseLandmarkType.leftElbow,
    wristT: PoseLandmarkType.leftWrist,
    hipT: PoseLandmarkType.leftHip,
    ankleT: PoseLandmarkType.leftAnkle,
  );
  final PushUpMetrics? right = _metricsForSide(
    pose: pose,
    shoulderT: PoseLandmarkType.rightShoulder,
    elbowT: PoseLandmarkType.rightElbow,
    wristT: PoseLandmarkType.rightWrist,
    hipT: PoseLandmarkType.rightHip,
    ankleT: PoseLandmarkType.rightAnkle,
  );
  if (left == null && right == null) return null;
  if (left == null) return right;
  if (right == null) return left;
  final double ls = _armSideScore(pose, isLeft: true);
  final double rs = _armSideScore(pose, isLeft: false);
  return ls >= rs ? left : right;
}

PoseFeedback analyzePushUp(Pose pose) {
  final PushUpMetrics? m = computePushUpMetrics(pose);
  if (m == null) {
    return PoseFeedback.noBody;
  }

  if (m.elbowAngleDeg > kPushUpElbowAngleTooOpenDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: 'Lower your chest — bend your elbows a bit more.',
      hintZh: '再下放一点，肘关节多弯曲一些。',
    );
  }

  if (m.hipDeviationFromStraightDeg > kPushUpMaxHipDeviationFromStraightDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: 'Keep shoulders, hips, and ankles in one straight line.',
      hintZh: '保持肩、髋、踝在一条直线上。',
    );
  }

  if (m.bodyAxisFromHorizontalDeg > kPushUpBodyAxisMaxFromHorizontalDeg ||
      !m.wristBelowShoulder) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: 'Turn sideways and keep your body line parallel to the floor.',
      hintZh: '请侧身入镜，并让身体主线尽量与地面平行。',
    );
  }

  return const PoseFeedback(
    kind: PoseFeedbackKind.good,
    headlineEn: 'Good',
    hintEn: 'Solid line — control the range of motion.',
    hintZh: '身体成线，动作不错。',
  );
}
