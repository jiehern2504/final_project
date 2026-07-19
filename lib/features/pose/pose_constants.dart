const int kPoseProcessEveryNFrames = 3;

const Duration kPoseUiFeedbackThrottle = Duration(milliseconds: 280);

const double kSquatKneeAngleTooHighDeg = 132;

const double kSquatKneeAngleGoodMinDeg = 75;

const double kSquatMaxTorsoLeanFromVerticalDeg = 38;

const double kPushUpElbowAngleTooOpenDeg = 158;

const double kPushUpMaxHipDeviationFromStraightDeg = 28;

const double kPushUpBodyAxisMaxFromHorizontalDeg = 42;

const double kGluteBridgeHipAngleTopMinDeg = 150;

const double kGluteBridgeHipAngleBottomMaxDeg = 130;

const double kGluteBridgeKneeIdealMinDeg = 60;
const double kGluteBridgeKneeIdealMaxDeg = 120;

const double kPlankBodyMinDeg = 155;
const double kPlankBodyMaxDeg = 195;

const Duration kPlankBadFormGrace = Duration(seconds: 5);

const double kPlankElbowMaxDeg = 175;

const double kCrunchCurledHipAngleMaxDeg = 122;

const double kCrunchRestHipAngleMinDeg = 150;

const double kCrunchReleaseDeltaDeg = 18;

const double kMinLandmarkLikelihood = 0.35;

const double kRepMinAvgLandmarkLikelihood = 0.45;

const Duration kRepCooldown = Duration(milliseconds: 700);

const double kRepPushUpBottomMaxDeg = 110;

const double kRepPushUpTopMinDeg = 145;

const double kRepPushUpMaxHipDeviationForRepDeg = 32;

const double kRepSquatDeepKneeMaxDeg = 112;

const double kRepSquatStandingKneeMinDeg = 125;

const double kRepSquatMaxTorsoLeanForCountDeg = 40;

const Duration kRepSquatMinDeepHold = Duration(milliseconds: 220);

const double kRepGluteBridgeTopMinDeg = 145;

const double kRepGluteBridgeBottomMaxDeg = 132;

const Duration kRepGluteBridgeMinTopHold = Duration(milliseconds: 150);

const double kRepCrunchUpMaxDeg = 122;

const double kRepCrunchDownMinDeg = 133;
