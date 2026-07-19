import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'analysis/pushup_analyzer.dart';
import 'analysis/squat_analyzer.dart';
import 'analysis/glutebridge_analyzer.dart';
import 'analysis/plank_analyzer.dart';
import 'analysis/crunch_analyzer.dart';
import 'pose_constants.dart';

double _avgLikelihood(Iterable<PoseLandmark?> landmarks) {
  final List<PoseLandmark> present = landmarks
      .whereType<PoseLandmark>()
      .toList();
  if (present.isEmpty) return 0;
  double sum = 0;
  for (final PoseLandmark l in present) {
    sum += l.likelihood;
  }
  return sum / present.length;
}

class PushUpRepCounter {
  int count = 0;
  bool _isLowered = false;
  DateTime? _lastRepTime;

  void reset() {
    count = 0;
    _isLowered = false;
    _lastRepTime = null;
  }

  void clearPhase() => _isLowered = false;

  bool _cooldownOk() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!) >= kRepCooldown;
  }

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

    if (m.hipDeviationFromStraightDeg > kRepPushUpMaxHipDeviationForRepDeg ||
        m.bodyAxisFromHorizontalDeg > kPushUpBodyAxisMaxFromHorizontalDeg ||
        !m.wristBelowShoulder) {
      _isLowered = false;
      return false;
    }

    if (m.elbowAngleDeg < kRepPushUpBottomMaxDeg) {
      _isLowered = true;
    } else if (m.elbowAngleDeg > kRepPushUpTopMinDeg &&
        _isLowered &&
        _cooldownOk()) {
      count++;
      _isLowered = false;
      _lastRepTime = DateTime.now();
    }

    return count != before;
  }
}

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
    final bool torsoOk =
        m.torsoLeanFromVerticalDeg <= kRepSquatMaxTorsoLeanForCountDeg;
    final DateTime now = DateTime.now();

    if (deepSquat && torsoOk) {
      if (!_isSquatting) {
        _isSquatting = true;
        _deepPhaseEnteredAt = now;
      }
    } else if (standing &&
        torsoOk &&
        _isSquatting &&
        _cooldownOk() &&
        _deepPhaseEnteredAt != null &&
        now.difference(_deepPhaseEnteredAt!) >= kRepSquatMinDeepHold) {
      count++;
      _isSquatting = false;
      _deepPhaseEnteredAt = null;
      _lastRepTime = now;
    }

    return count != before;
  }
}

class GluteBridgeRepCounter {
  int count = 0;
  bool _isRaised = false;
  DateTime? _lastRepTime;
  DateTime? _topPhaseEnteredAt;

  void reset() {
    count = 0;
    _isRaised = false;
    _lastRepTime = null;
    _topPhaseEnteredAt = null;
  }

  void clearPhase() {
    _isRaised = false;
    _topPhaseEnteredAt = null;
  }

  bool _cooldownOk() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!) >= kRepCooldown;
  }

  bool update(Pose pose) {
    final int before = count;
    final GluteBridgeMetrics? m = computeGluteBridgeMetrics(pose);
    if (m == null) {
      _isRaised = false;
      return false;
    }

    final double conf = _avgLikelihood(<PoseLandmark?>[
      pose.landmarks[PoseLandmarkType.leftShoulder],
      pose.landmarks[PoseLandmarkType.rightShoulder],
      pose.landmarks[PoseLandmarkType.leftHip],
      pose.landmarks[PoseLandmarkType.rightHip],
      pose.landmarks[PoseLandmarkType.leftKnee],
      pose.landmarks[PoseLandmarkType.rightKnee],
    ]);
    if (conf < kRepMinAvgLandmarkLikelihood) {
      _isRaised = false;
      return false;
    }

    final bool top = m.hipAngleDeg >= kRepGluteBridgeTopMinDeg;
    final bool bottom = m.hipAngleDeg <= kRepGluteBridgeBottomMaxDeg;
    final DateTime now = DateTime.now();

    if (top) {
      if (!_isRaised) {
        _isRaised = true;
        _topPhaseEnteredAt = now;
      }
    } else if (bottom &&
        _isRaised &&
        _cooldownOk() &&
        _topPhaseEnteredAt != null &&
        now.difference(_topPhaseEnteredAt!) >= kRepGluteBridgeMinTopHold) {
      count++;
      _isRaised = false;
      _topPhaseEnteredAt = null;
      _lastRepTime = now;
    }

    return count != before;
  }
}

class PlankHoldTimer {
  int seconds = 0;

  double _accumSeconds = 0;

  DateTime? _lastGoodTick;

  DateTime? _badFormStart;

  void reset() {
    seconds = 0;
    _accumSeconds = 0;
    _lastGoodTick = null;
    _badFormStart = null;
  }

  void clearPhase() {
    _lastGoodTick = null;
    _badFormStart = null;
  }

  bool update(Pose pose) {
    final int before = seconds;
    final PlankMetrics? m = computePlankMetrics(pose);
    final DateTime now = DateTime.now();

    final bool goodForm =
        m != null && (m.bodyAngleDeg - 180).abs() <= (180 - kPlankBodyMinDeg);

    if (goodForm) {
      _badFormStart = null;
      if (_lastGoodTick != null) {
        _accumSeconds += now.difference(_lastGoodTick!).inMilliseconds / 1000.0;
      }
      _lastGoodTick = now;
    } else {
      _lastGoodTick = null;
      _badFormStart ??= now;
      if (now.difference(_badFormStart!) >= kPlankBadFormGrace) {
        _accumSeconds = 0;
      }
    }

    seconds = _accumSeconds.floor();
    return seconds != before;
  }
}

class CrunchRepCounter {
  int count = 0;
  double _peakAngle = 999;
  bool _curledEnough = false;
  DateTime? _lastRepTime;

  void reset() {
    count = 0;
    _peakAngle = 999;
    _curledEnough = false;
    _lastRepTime = null;
  }

  void clearPhase() {
    _peakAngle = 999;
    _curledEnough = false;
  }

  bool _cooldownOk() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!) >= kRepCooldown;
  }

  bool update(Pose pose) {
    final int before = count;
    final CrunchMetrics? m = computeCrunchMetrics(pose);
    if (m == null) {
      debugPrint('CRUNCH null (no metric)');
      return false;
    }

    final double conf = _avgLikelihood(<PoseLandmark?>[
      pose.landmarks[PoseLandmarkType.leftShoulder],
      pose.landmarks[PoseLandmarkType.rightShoulder],
      pose.landmarks[PoseLandmarkType.leftHip],
      pose.landmarks[PoseLandmarkType.rightHip],
      pose.landmarks[PoseLandmarkType.leftKnee],
      pose.landmarks[PoseLandmarkType.rightKnee],
    ]);

    final double hip = m.hipAngleDeg;
    debugPrint(
      'CRUNCH hip=${hip.toStringAsFixed(0)} '
      'peak=${_peakAngle > 900 ? "-" : _peakAngle.toStringAsFixed(0)} '
      'curled=$_curledEnough count=$count conf=${conf.toStringAsFixed(2)}',
    );
    if (conf < kRepMinAvgLandmarkLikelihood) return false;

    if (hip < _peakAngle) _peakAngle = hip;
    if (_peakAngle <= kRepCrunchUpMaxDeg) _curledEnough = true;

    if (_curledEnough &&
        hip >= _peakAngle + kCrunchReleaseDeltaDeg &&
        _cooldownOk()) {
      count++;
      _lastRepTime = DateTime.now();
      _peakAngle = 999;
      _curledEnough = false;
    }

    return count != before;
  }
}
