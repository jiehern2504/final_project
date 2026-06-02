// Tunable thresholds for pose heuristics (document in reports / tuning).

/// Skip this many frames between ML Kit runs (1 = process every frame).
const int kPoseProcessEveryNFrames = 3;

/// Minimum time between overlay text updates (reduces flicker).
const Duration kPoseUiFeedbackThrottle = Duration(milliseconds: 280);

/// Squat: knee internal angle (hip–knee–ankle). Above this → not low enough.
const double kSquatKneeAngleTooHighDeg = 132;

/// Squat: knee internal angle in a “good” depth band (optional upper cap).
const double kSquatKneeAngleGoodMinDeg = 75;

/// Squat: torso (shoulder→hip) vs vertical — warn if larger than this (degrees).
const double kSquatMaxTorsoLeanFromVerticalDeg = 38;

/// Push-up: elbow internal angle (shoulder–elbow–wrist). Above → arms too straight.
const double kPushUpElbowAngleTooOpenDeg = 158;

/// Push-up: “plank” angle at hip (shoulder–hip–ankle). Deviation from 180°.
const double kPushUpMaxHipDeviationFromStraightDeg = 28;

/// Push-up: shoulder→ankle body axis must stay near horizontal (side view).
/// 0° means perfectly horizontal, 90° means vertical standing posture.
const double kPushUpBodyAxisMaxFromHorizontalDeg = 42;

/// Landmarks with likelihood below this are treated as unreliable.
const double kMinLandmarkLikelihood = 0.35;

// --- Rep counting (realtime_exercises-style state machines; tune for your space) ---

/// Push-up: elbows below this angle → “bottom” phase.
/// 110 is more tolerant for side-view variance on phone cameras.
const double kRepPushUpBottomMaxDeg = 110;

/// Push-up: elbows above this angle → completed rep when rising from bottom.
/// Keep lower than strict lockout to avoid missing valid reps.
const double kRepPushUpTopMinDeg = 145;

/// Plank check: shoulder–hip–knee angle must stay in this band (degrees).
const double kRepPlankTorsoMinDeg = 160;
const double kRepPlankTorsoMaxDeg = 180;

/// Squat: average knee internal angle below this enters squat phase.
/// Kept looser than strict "ATG" depth so "good" squats can still count.
const double kRepSquatDeepKneeMaxDeg = 112;

/// Squat: knee angle must be below this to count as “standing” reset (avoid noise).
const double kRepSquatStandingKneeMinDeg = 125;

/// Squat reps require torso lean within this limit (degrees from vertical).
const double kRepSquatMaxTorsoLeanForCountDeg = 40;

/// Squat must stay in "deep" phase for at least this long before counting.
const Duration kRepSquatMinDeepHold = Duration(milliseconds: 220);

/// Minimum average landmark likelihood before reps can advance (reduces false counts).
const double kRepMinAvgLandmarkLikelihood = 0.45;

/// Cooldown after a counted rep to avoid double-counting jitter.
const Duration kRepCooldown = Duration(milliseconds: 700);

/// Push-up reps: max shoulder–hip–ankle deviation from 180° while counting.
const double kRepPushUpMaxHipDeviationForRepDeg = 32;
