import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose_constants.dart';
import '../pose_geometry.dart';
import 'pose_feedback.dart';

bool _usable(PoseLandmark? l) =>
    l != null && l.likelihood >= kMinLandmarkLikelihood;

/// Key angles captured during a glute bridge.
class GluteBridgeMetrics {
  const GluteBridgeMetrics({
    required this.hipAngleDeg,
    required this.kneeAngleDeg,
  });

  /// Shoulder–hip–knee angle. Near 180° = hips fully raised.
  final double hipAngleDeg;

  /// Hip–knee–ankle angle. Should stay around 80–100° for foot placement.
  final double kneeAngleDeg;
}

/// Picks the side with better landmark confidence.
GluteBridgeMetrics? computeGluteBridgeMetrics(Pose pose) {
  final GluteBridgeMetrics? left = _metricsForSide(
    pose: pose,
    shoulderT: PoseLandmarkType.leftShoulder,
    hipT: PoseLandmarkType.leftHip,
    kneeT: PoseLandmarkType.leftKnee,
    ankleT: PoseLandmarkType.leftAnkle,
  );
  final GluteBridgeMetrics? right = _metricsForSide(
    pose: pose,
    shoulderT: PoseLandmarkType.rightShoulder,
    hipT: PoseLandmarkType.rightHip,
    kneeT: PoseLandmarkType.rightKnee,
    ankleT: PoseLandmarkType.rightAnkle,
  );

  if (left == null && right == null) return null;
  if (left == null) return right;
  if (right == null) return left;

  // Prefer the side whose landmarks are more confident.
  final double leftConf  = _sideConfidence(pose, isLeft: true);
  final double rightConf = _sideConfidence(pose, isLeft: false);
  return leftConf >= rightConf ? left : right;
}

GluteBridgeMetrics? _metricsForSide({
  required Pose pose,
  required PoseLandmarkType shoulderT,
  required PoseLandmarkType hipT,
  required PoseLandmarkType kneeT,
  required PoseLandmarkType ankleT,
}) {
  final PoseLandmark? shoulder = pose.landmarks[shoulderT];
  final PoseLandmark? hip      = pose.landmarks[hipT];
  final PoseLandmark? knee     = pose.landmarks[kneeT];
  final PoseLandmark? ankle    = pose.landmarks[ankleT];

  if (!_usable(shoulder) || !_usable(hip) || !_usable(knee) || !_usable(ankle)) {
    return null;
  }

  final double hipAngle  = angleAtPoseLandmarks(shoulder!, hip!, knee!);
  final double kneeAngle = angleAtPoseLandmarks(hip, knee, ankle!);

  return GluteBridgeMetrics(hipAngleDeg: hipAngle, kneeAngleDeg: kneeAngle);
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

/// Returns [PoseFeedback] describing glute bridge form.
PoseFeedback analyzeGluteBridge(Pose pose) {
  final GluteBridgeMetrics? m = computeGluteBridgeMetrics(pose);
  if (m == null) return PoseFeedback.noBody;

  // Check knee angle first — bad foot placement makes everything else wrong.
  if (m.kneeAngleDeg < kGluteBridgeKneeIdealMinDeg ||
      m.kneeAngleDeg > kGluteBridgeKneeIdealMaxDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: 'Place your feet flat — knees should be at about 90°.',
    );
  }

  if (m.hipAngleDeg < kGluteBridgeHipAngleTopMinDeg) {
    return const PoseFeedback(
      kind: PoseFeedbackKind.adjust,
      headlineEn: 'Adjust',
      hintEn: 'Raise your hips higher — squeeze your glutes at the top.',
    );
  }

  return const PoseFeedback(
    kind: PoseFeedbackKind.good,
    headlineEn: 'Good',
    hintEn: 'Hips are up — hold and squeeze for a second.',
  );
}