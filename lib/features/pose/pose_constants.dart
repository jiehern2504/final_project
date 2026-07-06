// Tunable thresholds for pose heuristics (document in reports / tuning).

/// Skip this many frames between ML Kit runs (1 = process every frame).
const int kPoseProcessEveryNFrames = 3;

/// Minimum time between overlay text updates (reduces flicker).
const Duration kPoseUiFeedbackThrottle = Duration(milliseconds: 280);

// ── Squat ──────────────────────────────────────────────────────────────────

/// Squat: knee internal angle (hip–knee–ankle). Above this → not low enough.
const double kSquatKneeAngleTooHighDeg = 132;

/// Squat: knee internal angle in a "good" depth band (optional upper cap).
const double kSquatKneeAngleGoodMinDeg = 75;

/// Squat: torso (shoulder→hip) vs vertical — warn if larger than this (degrees).
const double kSquatMaxTorsoLeanFromVerticalDeg = 38;

// ── Push-up ────────────────────────────────────────────────────────────────

/// Push-up: elbow internal angle (shoulder–elbow–wrist). Above → arms too straight.
const double kPushUpElbowAngleTooOpenDeg = 158;

/// Push-up: "plank" angle at hip (shoulder–hip–ankle). Deviation from 180°.
const double kPushUpMaxHipDeviationFromStraightDeg = 28;

/// Push-up: shoulder→ankle body axis must stay near horizontal (side view).
/// 0° means perfectly horizontal, 90° means vertical standing posture.
const double kPushUpBodyAxisMaxFromHorizontalDeg = 42;

// ── Lunge ──────────────────────────────────────────────────────────────────

/// Lunge: front knee angle (hip–knee–ankle) below this → good depth.
/// Tuned from real ML Kit data (a proper lunge reaches ~70–100°).
const double kLungeFrontKneeGoodMaxDeg = 120;

/// Lunge: front knee angle above this → not low enough yet.
const double kLungeFrontKneeTooHighDeg = 145;

/// Lunge: back knee angle (hip–knee–ankle) should be roughly 90°.
/// Below this value = back knee too collapsed.
const double kLungeBackKneeMinDeg = 70;

/// Lunge: torso lean from vertical. Excessive forward lean = warn.
const double kLungeMaxTorsoLeanDeg = 35;

// ── Glute Bridge ───────────────────────────────────────────────────────────

/// Glute Bridge: hip angle (shoulder–hip–knee) at the TOP position.
/// Should be close to flat (≈ 180°). Below this → hips not raised enough.
const double kGluteBridgeHipAngleTopMinDeg = 150;

/// Glute Bridge: hip angle at the BOTTOM (resting) position.
/// Above this threshold → user has lowered hips back down.
const double kGluteBridgeHipAngleBottomMaxDeg = 130;

/// Glute Bridge: knee angle (hip–knee–ankle) — should stay around 90°.
/// If too straight the user has wrong foot placement.
const double kGluteBridgeKneeIdealMinDeg = 60;
const double kGluteBridgeKneeIdealMaxDeg = 120;

// ── Plank ──────────────────────────────────────────────────────────────────

/// Plank: shoulder–hip–ankle angle. Must stay in this band (degrees).
const double kPlankBodyMinDeg = 155;
const double kPlankBodyMaxDeg = 195;  // allow slight upward tilt

/// Plank: how long form may stay broken before the held-seconds reset.
/// A short slip won't wipe the count — only sustained bad form does.
const Duration kPlankBadFormGrace = Duration(seconds: 5);

/// Plank: elbow angle (shoulder–elbow–wrist). Forearm plank ≈ 90°.
/// Above this = arms too straight → likely high plank, still ok to count.
const double kPlankElbowMaxDeg = 175;

// ── Crunch ─────────────────────────────────────────────────────────────────

/// Crunch: angle at hip (shoulder–hip–knee) when CURLED UP.
/// Below this threshold → shoulders lifted enough for a crunch.
/// Measured with BENT KNEES: the curl bottoms out around ~110–120°.
const double kCrunchCurledHipAngleMaxDeg = 122;

/// Crunch: only nag "curl up more" when clearly flat/legs-extended (well above
/// the ~135° a relaxed bent-knee position reads), so a normal crunch isn't red.
const double kCrunchRestHipAngleMinDeg = 150;

/// Crunch: how far the hip angle must rise back from its deepest curl (peak) to
/// count one rep. Relative to the peak, so it adapts to how deep the user curls
/// and avoids the double-counting a fixed narrow band caused.
const double kCrunchReleaseDeltaDeg = 18;

// ── Rep counting shared ────────────────────────────────────────────────────

/// Landmarks with likelihood below this are treated as unreliable.
const double kMinLandmarkLikelihood = 0.35;

/// Minimum average landmark likelihood before reps can advance.
const double kRepMinAvgLandmarkLikelihood = 0.45;

/// Cooldown after a counted rep to avoid double-counting jitter.
const Duration kRepCooldown = Duration(milliseconds: 700);

// ── Push-up rep counting ───────────────────────────────────────────────────

/// Push-up: elbows below this angle → "bottom" phase.
const double kRepPushUpBottomMaxDeg = 110;

/// Push-up: elbows above this angle → completed rep when rising from bottom.
const double kRepPushUpTopMinDeg = 145;

/// Push-up: max hip deviation while counting.
const double kRepPushUpMaxHipDeviationForRepDeg = 32;

// ── Squat rep counting ─────────────────────────────────────────────────────

/// Squat: average knee internal angle below this enters squat phase.
const double kRepSquatDeepKneeMaxDeg = 112;

/// Squat: knee angle must be below this to count as "standing" reset.
const double kRepSquatStandingKneeMinDeg = 125;

/// Squat reps require torso lean within this limit.
const double kRepSquatMaxTorsoLeanForCountDeg = 40;

/// Squat must stay in "deep" phase for at least this long before counting.
const Duration kRepSquatMinDeepHold = Duration(milliseconds: 220);

// ── Lunge rep counting ─────────────────────────────────────────────────────

/// Lunge: front knee below this angle → "lunge" phase entered.
const double kRepLungeDeepKneeMaxDeg = 115;

/// Lunge: front knee above this angle → standing reset.
/// Lowered from 155 → 150 so the rep reliably resets (measured standing ≈ 156–173°).
const double kRepLungeStandingKneeMinDeg = 150;

/// Lunge must hold deep position for this long before counting.
const Duration kRepLungeMinDeepHold = Duration(milliseconds: 100);

// ── Glute Bridge rep counting ──────────────────────────────────────────────

/// Hip angle above this → "top" phase (hips raised).
const double kRepGluteBridgeTopMinDeg = 145;

/// Hip angle below this → "bottom" phase (hips lowered).
const double kRepGluteBridgeBottomMaxDeg = 132;

/// Minimum hold at top before counting.
const Duration kRepGluteBridgeMinTopHold = Duration(milliseconds: 150);

// ── Crunch rep counting ────────────────────────────────────────────────────

/// Shoulder–hip–knee angle below this → "up" phase (curled).
/// Measured with bent knees: the curl reaches ~110–120°.
const double kRepCrunchUpMaxDeg = 122;

/// Shoulder–hip–knee angle above this → "down" phase (relaxed → counts a rep).
/// With bent knees the relaxed angle is only ~135° (not ~180°), so requiring a
/// higher value here is why reps never counted before.
const double kRepCrunchDownMinDeg = 133;