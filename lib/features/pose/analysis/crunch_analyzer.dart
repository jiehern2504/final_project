import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose_constants.dart';
import '../pose_geometry.dart';
import 'pose_feedback.dart';

bool _usable(PoseLandmark? l) =>
    l != null && l.likelihood >= kMinLandmarkLikelihood;

/// Key angles for a crunch.
class CrunchMetrics {
  const CrunchMetrics({required this.hipAngleDeg});

  /// Shoulder–hip–knee angle.
  /// Small angle = curled up; large angle = lying flat.
  final double hipAngleDeg;
}

/// Picks the side with better landmark confidence.
CrunchMetrics? computeCrunchMetrics(Pose pose) {
  final CrunchMetrics? left = _metricsForSide(
    pose: pose,
    shoulderT: PoseLandmarkType.leftShoulder,
    hipT:      PoseLandmarkType.leftHip,
    kneeT:     PoseLandmarkType.leftKnee,
  );
  final CrunchMetrics? right = _metricsForSide(
    pose: pose,
    shoulderT: PoseLandmarkType.rightShoulder,
    hipT:      PoseLandmarkType.rightHip,
    kneeT:     PoseLandmarkType.rightKnee,
  );

  if (left == null && right == null) return null;
  if (left == null) return right;
  if (right == null) return left;

  final double ls = _sideConfidence(pose, isLeft: true);
  final double rs = _sideConfidence(pose, isLeft: false);
  return ls >= rs ? left : right;
}

CrunchMetrics? _metricsForSide({
  required Pose pose,
  required PoseLandmarkType shoulderT,
  required PoseLandmarkType hipT,
  required PoseLandmarkType kneeT,
}) {
  final PoseLandmark? shoulder = pose.landmarks[shoulderT];
  final PoseLandmark? hip      = pose.landmarks[hipT];
  final PoseLandmark? knee     = pose.landmarks[kneeT];

  if (!_usable(shoulder) || !_usable(hip) || !_usable(knee)) return null;

  final double hipAngle = angleAtPoseLandmarks(shoulder!, hip!, knee!);
  return CrunchMetrics(hipAngleDeg: hipAngle);
}

double _sideConfidence(Pose pose, {required bool isLeft}) {
  final PoseLandmark? s = pose.landmarks[isLeft
      ? PoseLandmarkType.leftShoulder
      : PoseLandmarkType.rightShoulder];
  final PoseLandmark? h = pose.landmarks[isLeft
      ? PoseLandmarkType.leftHip
      : PoseLandmarkType.rightHip];
  final PoseLandmark? k = pose.landmarks[isLeft
      ? PoseLandmarkType.leftKnee
      : PoseLandmarkType.rightKnee];
  if (s == null || h == null || k == null) return 0;
  return (s.likelihood + h.likelihood + k.likelihood) / 3;
}

/// Returns [PoseFeedback] describing crunch form.
PoseFeedback analyzeCrunch(Pose pose) {
  final CrunchMetrics? m = computeCrunchMetrics(pose);
  if (m == null) return PoseFeedback.noBody;

  if (m.hipAngleDeg > kCrunchRestHipAngleMinDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: 'Curl up more — lift your shoulders off the floor.',
    );
  }

  if (m.hipAngleDeg <= kCrunchCurledHipAngleMaxDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.good,
      headlineEn: 'Good',
      hintEn: 'Good crunch — hold briefly then lower slowly.',
    );
  }

  return const PoseFeedback(
    kind: PoseFeedbackKind.good,
    headlineEn: 'Good',
    hintEn: 'Nice form — keep your lower back pressed down.',
  );
}