import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'analysis/pushup_analyzer.dart';
import 'analysis/squat_analyzer.dart';
import 'analysis/lunge_analyzer.dart';
import 'analysis/glutebridge_analyzer.dart';
import 'analysis/plank_analyzer.dart';
import 'analysis/crunch_analyzer.dart';
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

// ── Push-up ────────────────────────────────────────────────────────────────

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

  void clearPhase() => _isLowered = false;

  bool _cooldownOk() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!) >= kRepCooldown;
  }

  bool update(Pose pose) {
    final int before = count;
    final PushUpMetrics? m = computePushUpMetrics(pose);
    if (m == null) { _isLowered = false; return false; }

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
    if (conf < kRepMinAvgLandmarkLikelihood) { _isLowered = false; return false; }

    if (m.hipDeviationFromStraightDeg > kRepPushUpMaxHipDeviationForRepDeg ||
        m.bodyAxisFromHorizontalDeg > kPushUpBodyAxisMaxFromHorizontalDeg ||
        !m.wristBelowShoulder) {
      _isLowered = false;
      return false;
    }

    if (m.elbowAngleDeg < kRepPushUpBottomMaxDeg) {
      _isLowered = true;
    } else if (m.elbowAngleDeg > kRepPushUpTopMinDeg && _isLowered && _cooldownOk()) {
      count++;
      _isLowered = false;
      _lastRepTime = DateTime.now();
    }

    return count != before;
  }
}

// ── Squat ──────────────────────────────────────────────────────────────────

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
    if (m == null) { _isSquatting = false; return false; }

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
    final bool standing  = m.kneeAngleDeg >= kRepSquatStandingKneeMinDeg;
    final bool torsoOk   = m.torsoLeanFromVerticalDeg <= kRepSquatMaxTorsoLeanForCountDeg;
    final DateTime now = DateTime.now();

    if (deepSquat && torsoOk) {
      if (!_isSquatting) {
        _isSquatting = true;
        _deepPhaseEnteredAt = now;
      }
    } else if (standing && torsoOk && _isSquatting && _cooldownOk() &&
        _deepPhaseEnteredAt != null &&
        now.difference(_deepPhaseEnteredAt!) >= kRepSquatMinDeepHold) {
      count++;
      _isSquatting = false;
      _deepPhaseEnteredAt = null;
      _lastRepTime = now;
    } else if (!deepSquat) {
      _isSquatting = false;
      _deepPhaseEnteredAt = null;
    }

    return count != before;
  }
}

// ── Lunge ──────────────────────────────────────────────────────────────────

/// Lunge rep counting — counts each time a front knee dips and returns up.
class LungeRepCounter {
  int count = 0;
  bool _isLunging = false;
  DateTime? _lastRepTime;
  DateTime? _deepPhaseEnteredAt;

  void reset() {
    count = 0;
    _isLunging = false;
    _lastRepTime = null;
    _deepPhaseEnteredAt = null;
  }

  void clearPhase() {
    _isLunging = false;
    _deepPhaseEnteredAt = null;
  }

  bool _cooldownOk() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!) >= kRepCooldown;
  }

  bool update(Pose pose) {
    final int before = count;
    final LungeMetrics? m = computeLungeMetrics(pose);
    if (m == null) { _isLunging = false; return false; }

    final double conf = _avgLikelihood(<PoseLandmark?>[
      pose.landmarks[PoseLandmarkType.leftHip],
      pose.landmarks[PoseLandmarkType.rightHip],
      pose.landmarks[PoseLandmarkType.leftKnee],
      pose.landmarks[PoseLandmarkType.rightKnee],
      pose.landmarks[PoseLandmarkType.leftAnkle],
      pose.landmarks[PoseLandmarkType.rightAnkle],
    ]);
    if (conf < kRepMinAvgLandmarkLikelihood) { _isLunging = false; return false; }

    final bool deep     = m.frontKneeAngleDeg < kRepLungeDeepKneeMaxDeg;
    final bool standing = m.frontKneeAngleDeg > kRepLungeStandingKneeMinDeg;
    final DateTime now  = DateTime.now();

    if (deep) {
      if (!_isLunging) {
        _isLunging = true;
        _deepPhaseEnteredAt = now;
      }
    } else if (standing && _isLunging && _cooldownOk() &&
        _deepPhaseEnteredAt != null &&
        now.difference(_deepPhaseEnteredAt!) >= kRepLungeMinDeepHold) {
      count++;
      _isLunging = false;
      _deepPhaseEnteredAt = null;
      _lastRepTime = now;
    } else if (!deep) {
      _isLunging = false;
      _deepPhaseEnteredAt = null;
    }

    return count != before;
  }
}

// ── Glute Bridge ───────────────────────────────────────────────────────────

/// Glute bridge rep counting — counts each hip raise + lower cycle.
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
    if (m == null) { _isRaised = false; return false; }

    final double conf = _avgLikelihood(<PoseLandmark?>[
      pose.landmarks[PoseLandmarkType.leftShoulder],
      pose.landmarks[PoseLandmarkType.rightShoulder],
      pose.landmarks[PoseLandmarkType.leftHip],
      pose.landmarks[PoseLandmarkType.rightHip],
      pose.landmarks[PoseLandmarkType.leftKnee],
      pose.landmarks[PoseLandmarkType.rightKnee],
    ]);
    if (conf < kRepMinAvgLandmarkLikelihood) { _isRaised = false; return false; }

    final bool top    = m.hipAngleDeg >= kRepGluteBridgeTopMinDeg;
    final bool bottom = m.hipAngleDeg <= kRepGluteBridgeBottomMaxDeg;
    final DateTime now = DateTime.now();

    if (top) {
      if (!_isRaised) {
        _isRaised = true;
        _topPhaseEnteredAt = now;
      }
    } else if (bottom && _isRaised && _cooldownOk() &&
        _topPhaseEnteredAt != null &&
        now.difference(_topPhaseEnteredAt!) >= kRepGluteBridgeMinTopHold) {
      count++;
      _isRaised = false;
      _topPhaseEnteredAt = null;
      _lastRepTime = now;
    } else if (!top) {
      _isRaised = false;
      _topPhaseEnteredAt = null;
    }

    return count != before;
  }
}

// ── Plank (timed) ──────────────────────────────────────────────────────────

/// Plank is a TIMED hold. Accumulates seconds spent in good form.
///
/// [seconds] is the display value shown in place of a rep count.
class PlankHoldTimer {
  int seconds = 0;
  DateTime? _goodFormStart;
  bool _inGoodForm = false;

  void reset() {
    seconds = 0;
    _goodFormStart = null;
    _inGoodForm = false;
  }

  void clearPhase() {
    _goodFormStart = null;
    _inGoodForm = false;
  }

  /// Returns true if [seconds] changed this frame.
  bool update(Pose pose) {
    final int before = seconds;
    final PlankMetrics? m = computePlankMetrics(pose);

    if (m == null) {
      _inGoodForm = false;
      _goodFormStart = null;
      return false;
    }

    final double dev = (m.bodyAngleDeg - 180).abs();
    final bool goodForm = dev <= (180 - kPlankBodyMinDeg);

    final DateTime now = DateTime.now();

    if (goodForm) {
      if (!_inGoodForm) {
        _inGoodForm = true;
        _goodFormStart = now;
      } else if (_goodFormStart != null) {
        seconds = now.difference(_goodFormStart!).inSeconds;
      }
    } else {
      _inGoodForm = false;
      _goodFormStart = null;
    }

    return seconds != before;
  }
}

// ── Crunch ─────────────────────────────────────────────────────────────────

/// Crunch rep counting — counts each curl-up + lower cycle.
class CrunchRepCounter {
  int count = 0;
  bool _isCurled = false;
  DateTime? _lastRepTime;

  void reset() {
    count = 0;
    _isCurled = false;
    _lastRepTime = null;
  }

  void clearPhase() => _isCurled = false;

  bool _cooldownOk() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!) >= kRepCooldown;
  }

  bool update(Pose pose) {
    final int before = count;
    final CrunchMetrics? m = computeCrunchMetrics(pose);
    if (m == null) { _isCurled = false; return false; }

    final double conf = _avgLikelihood(<PoseLandmark?>[
      pose.landmarks[PoseLandmarkType.leftShoulder],
      pose.landmarks[PoseLandmarkType.rightShoulder],
      pose.landmarks[PoseLandmarkType.leftHip],
      pose.landmarks[PoseLandmarkType.rightHip],
      pose.landmarks[PoseLandmarkType.leftKnee],
      pose.landmarks[PoseLandmarkType.rightKnee],
    ]);
    if (conf < kRepMinAvgLandmarkLikelihood) { _isCurled = false; return false; }

    final bool curled  = m.hipAngleDeg <= kRepCrunchUpMaxDeg;
    final bool resting = m.hipAngleDeg >= kRepCrunchDownMinDeg;

    if (curled) {
      _isCurled = true;
    } else if (resting && _isCurled && _cooldownOk()) {
      count++;
      _isCurled = false;
      _lastRepTime = DateTime.now();
    }

    return count != before;
  }
}