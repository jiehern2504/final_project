import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'analysis/pushup_analyzer.dart';
import 'analysis/squat_analyzer.dart';
import 'pose_constants.dart';

double _avgLikelihood(Iterable<PoseLandmark?> landmarks) {
  final List<PoseLandmark> present =
      landmarks.whereType<PoseLandmark>().toList();
  if (present.isEmpty) return 0;
  double sum = 0;
  for (final PoseLandmark l in present) {
    sum += l.likelihood;
  }
  return sum / present.length;
}

/// Push-up rep counting with confidence + plank gate + cooldown.
class PushUpRepCounter {
  int count = 0;
  bool _isLowered = false;
  DateTime? _lastRepTime;

  void reset() {
    count = 0;
    _isLowered = false;
    _lastRepTime = null;
  }

  /// Clears partial rep state when no pose is detected (does not reset [count]).
  void clearPhase() {
    _isLowered = false;
  }

  bool _cooldownOk() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!) >= kRepCooldown;
  }

  /// Returns true if [count] changed.
  bool update(Pose pose) {
    final int before = count;

    final PushUpMetrics? m = computePushUpMetrics(pose);
    if (m == null) {
      _isLowered = false;
      return false;
    }

    final double conf = _avgLikelihood(<PoseLandmark?>[
      pose.landmarks[PoseLandmarkType.leftShoulder],
      pose.landmarks[PoseLandmarkType.rightShoulder],
      pose.landmarks[PoseLandmarkType.leftElbow],
      pose.landmarks[PoseLandmarkType.rightElbow],
      pose.landmarks[PoseLandmarkType.leftWrist],
      pose.landmarks[PoseLandmarkType.rightWrist],
      pose.landmarks[PoseLandmarkType.leftHip],
      pose.landmarks[PoseLandmarkType.rightHip],
    ]);
    if (conf < kRepMinAvgLandmarkLikelihood) {
      _isLowered = false;
      return false;
    }

    if (m.hipDeviationFromStraightDeg > kRepPushUpMaxHipDeviationForRepDeg) {
      _isLowered = false;
      return false;
    }
    if (m.bodyAxisFromHorizontalDeg > kPushUpBodyAxisMaxFromHorizontalDeg ||
        !m.wristBelowShoulder) {
      _isLowered = false;
      return false;
    }

    final double avgElbowAngle = m.elbowAngleDeg;
    final bool inPlankPosition =
        m.hipDeviationFromStraightDeg <= kRepPushUpMaxHipDeviationForRepDeg;

    if (avgElbowAngle < kRepPushUpBottomMaxDeg && inPlankPosition) {
      _isLowered = true;
    } else if (avgElbowAngle > kRepPushUpTopMinDeg &&
        _isLowered &&
        inPlankPosition &&
        _cooldownOk()) {
      count++;
      _isLowered = false;
      _lastRepTime = DateTime.now();
    }

    return count != before;
  }
}

/// Squat rep counting with confidence + depth gate + cooldown.
class SquatRepCounter {
  int count = 0;
  bool _isSquatting = false;
  DateTime? _lastRepTime;
  DateTime? _deepPhaseEnteredAt;

  void reset() {
    count = 0;
    _isSquatting = false;
    _lastRepTime = null;
    _deepPhaseEnteredAt = null;
  }

  void clearPhase() {
    _isSquatting = false;
    _deepPhaseEnteredAt = null;
  }

  bool _cooldownOk() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!) >= kRepCooldown;
  }

  bool update(Pose pose) {
    final int before = count;

    final SquatMetrics? m = computeSquatMetrics(pose);
    if (m == null) {
      _isSquatting = false;
      return false;
    }

    final double conf = _avgLikelihood(<PoseLandmark?>[
      pose.landmarks[PoseLandmarkType.leftHip],
      pose.landmarks[PoseLandmarkType.rightHip],
      pose.landmarks[PoseLandmarkType.leftKnee],
      pose.landmarks[PoseLandmarkType.rightKnee],
      pose.landmarks[PoseLandmarkType.leftAnkle],
      pose.landmarks[PoseLandmarkType.rightAnkle],
    ]);
    if (conf < kRepMinAvgLandmarkLikelihood) {
      _isSquatting = false;
      _deepPhaseEnteredAt = null;
      return false;
    }

    final bool deepSquat = m.kneeAngleDeg < kRepSquatDeepKneeMaxDeg;
    final bool standing = m.kneeAngleDeg >= kRepSquatStandingKneeMinDeg;
    final bool torsoStable =
        m.torsoLeanFromVerticalDeg <= kRepSquatMaxTorsoLeanForCountDeg;
    final DateTime now = DateTime.now();

    if (deepSquat && torsoStable) {
      if (!_isSquatting) {
        _isSquatting = true;
        _deepPhaseEnteredAt = now;
      }
    } else if (standing &&
        torsoStable &&
        _isSquatting &&
        _cooldownOk() &&
        _deepPhaseEnteredAt != null &&
        now.difference(_deepPhaseEnteredAt!) >= kRepSquatMinDeepHold) {
      count++;
      _isSquatting = false;
      _deepPhaseEnteredAt = null;
      _lastRepTime = now;
    } else if (!deepSquat) {
      // Reset partial phase when user exits squat without completing a rep.
      _isSquatting = false;
      _deepPhaseEnteredAt = null;
    }

    return count != before;
  }
}
