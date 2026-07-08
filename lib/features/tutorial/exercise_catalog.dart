import '../pose/pose_exercise_type.dart';
import 'muscle_models.dart';

enum ExerciseVideoAngle { front, side }

extension ExerciseVideoAngleLabel on ExerciseVideoAngle {
  String get label => this == ExerciseVideoAngle.front ? 'Front' : 'Side';
}

class TutorialExercise {
  const TutorialExercise({
    required this.id,
    required this.muscle,
    required this.title,
    required this.subtitle,
    required this.frontStoragePath,
    required this.sideStoragePath,
    this.poseDetectType,
  });

  final String id;
  final MuscleId muscle;
  final String title;
  final String subtitle;
  final String frontStoragePath;
  final String sideStoragePath;
  final PoseExerciseType? poseDetectType;

  String storagePathFor(ExerciseVideoAngle angle) =>
      angle == ExerciseVideoAngle.front ? frontStoragePath : sideStoragePath;
}

const List<TutorialExercise> _allExercises = [
  TutorialExercise(
    id: 'bench_dips_chair',
    muscle: MuscleId.arms,
    title: 'Bench Dips (Chair)',
    subtitle: '3 sets • 8–12 reps',
    frontStoragePath: 'tutorial_videos/arms/bench_dips_chair/front.mp4',
    sideStoragePath: 'tutorial_videos/arms/bench_dips_chair/side.mp4',
  ),
  TutorialExercise(
    id: 'diamond_knee_push_ups',
    muscle: MuscleId.arms,
    title: 'Diamond Knee Push-ups',
    subtitle: '3 sets • 6–10 reps',
    frontStoragePath: 'tutorial_videos/arms/diamond_knee_push_ups/front.mp4',
    sideStoragePath: 'tutorial_videos/arms/diamond_knee_push_ups/side.mp4',
  ),
  TutorialExercise(
    id: 'triceps_extensions',
    muscle: MuscleId.arms,
    title: 'Triceps Extensions',
    subtitle: '3 sets • 6–10 reps',
    frontStoragePath: 'tutorial_videos/arms/triceps_extensions/front.mp4',
    sideStoragePath: 'tutorial_videos/arms/triceps_extensions/side.mp4',
  ),
  TutorialExercise(
    id: 'push_ups',
    muscle: MuscleId.chest,
    title: 'Push-ups',
    subtitle: '3 sets • 8–12 reps',
    frontStoragePath: 'tutorial_videos/chest/push_ups/front.mp4',
    sideStoragePath: 'tutorial_videos/chest/push_ups/side.mp4',
    poseDetectType: PoseExerciseType.pushUp,
  ),
  TutorialExercise(
    id: 'incline_push_ups',
    muscle: MuscleId.chest,
    title: 'Incline Push-ups',
    subtitle: '3 sets • 8–15 reps',
    frontStoragePath: 'tutorial_videos/chest/incline_push_ups/front.mp4',
    sideStoragePath: 'tutorial_videos/chest/incline_push_ups/side.mp4',
  ),
  TutorialExercise(
    id: 'decline_push_ups',
    muscle: MuscleId.chest,
    title: 'Decline Push-ups',
    subtitle: '3 sets • 6–12 reps',
    frontStoragePath: 'tutorial_videos/chest/decline_push_ups/front.mp4',
    sideStoragePath: 'tutorial_videos/chest/decline_push_ups/side.mp4',
  ),
  TutorialExercise(
    id: 'crunches',
    muscle: MuscleId.abs,
    title: 'Crunches',
    subtitle: '3 sets • 12–20 reps',
    frontStoragePath: 'tutorial_videos/abs/crunches/front.mp4',
    sideStoragePath: 'tutorial_videos/abs/crunches/side.mp4',
    poseDetectType: PoseExerciseType.crunch,
  ),
  TutorialExercise(
    id: 'laying_leg_raises',
    muscle: MuscleId.abs,
    title: 'Laying Leg Raises',
    subtitle: '3 sets • 8–12 reps',
    frontStoragePath: 'tutorial_videos/abs/laying_leg_raises/front.mp4',
    sideStoragePath: 'tutorial_videos/abs/laying_leg_raises/side.mp4',
  ),
  TutorialExercise(
    id: 'hand_plank',
    muscle: MuscleId.abs,
    title: 'Hand Plank',
    subtitle: '3 sets • 30–60 sec',
    frontStoragePath: 'tutorial_videos/abs/hand_plank/front.mp4',
    sideStoragePath: 'tutorial_videos/abs/hand_plank/side.mp4',
    poseDetectType: PoseExerciseType.plank,
  ),
  TutorialExercise(
    id: 'bodyweight_squats',
    muscle: MuscleId.legs,
    title: 'Bodyweight Squats',
    subtitle: '3 sets • 10–15 reps',
    frontStoragePath: 'tutorial_videos/legs/bodyweight_squats/front.mp4',
    sideStoragePath: 'tutorial_videos/legs/bodyweight_squats/side.mp4',
    poseDetectType: PoseExerciseType.squat,
  ),
  TutorialExercise(
    id: 'forward_lunges',
    muscle: MuscleId.legs,
    title: 'Forward Lunges',
    subtitle: '3 sets • 8–12 reps/side',
    frontStoragePath: 'tutorial_videos/legs/forward_lunges/front.mp4',
    sideStoragePath: 'tutorial_videos/legs/forward_lunges/side.mp4',
  ),
  TutorialExercise(
    id: 'bulgarian_split_squats',
    muscle: MuscleId.legs,
    title: 'Bulgarian Split Squats',
    subtitle: '3 sets • 10–15 reps',
    frontStoragePath: 'tutorial_videos/legs/bulgarian_split_squats/front.mp4',
    sideStoragePath: 'tutorial_videos/legs/bulgarian_split_squats/side.mp4',
  ),
  TutorialExercise(
    id: 'pike_push_ups',
    muscle: MuscleId.shoulders,
    title: 'Pike Push-ups',
    subtitle: '3 sets • 6–10 reps',
    frontStoragePath: 'tutorial_videos/shoulders/pike_push_ups/front.mp4',
    sideStoragePath: 'tutorial_videos/shoulders/pike_push_ups/side.mp4',
  ),
  TutorialExercise(
    id: 'forward_arm_circles',
    muscle: MuscleId.shoulders,
    title: 'Forward Arm Circles',
    subtitle: '3 sets • 8-12 reps',
    frontStoragePath: 'tutorial_videos/shoulders/forward_arm_circles/front.mp4',
    sideStoragePath: 'tutorial_videos/shoulders/forward_arm_circles/side.mp4',
  ),
  TutorialExercise(
    id: 'backward_arm_circle',
    muscle: MuscleId.shoulders,
    title: 'Backward Arm Circle',
    subtitle: '3 sets • 8-12 reps',
    frontStoragePath: 'tutorial_videos/shoulders/backward_arm_circle/front.mp4',
    sideStoragePath: 'tutorial_videos/shoulders/backward_arm_circle/side.mp4',
  ),
  TutorialExercise(
    id: 'plate_superman_hold',
    muscle: MuscleId.back,
    title: 'Plate Superman Hold',
    subtitle: '3 sets • 20–40 sec',
    frontStoragePath: 'tutorial_videos/back/plate_superman_hold/front.mp4',
    sideStoragePath: 'tutorial_videos/back/plate_superman_hold/side.mp4',
  ),
  TutorialExercise(
    id: 'superman',
    muscle: MuscleId.back,
    title: 'Superman',
    subtitle: '3 sets • 10–15 reps',
    frontStoragePath: 'tutorial_videos/back/superman/front.mp4',
    sideStoragePath: 'tutorial_videos/back/superman/side.mp4',
  ),
  TutorialExercise(
    id: 'superman_pull',
    muscle: MuscleId.back,
    title: 'Superman Pull',
    subtitle: '3 sets • 8–12 reps',
    frontStoragePath: 'tutorial_videos/back/superman_pull/front.mp4',
    sideStoragePath: 'tutorial_videos/back/superman_pull/side.mp4',
  ),
  TutorialExercise(
    id: 'glute_bridges',
    muscle: MuscleId.glutes,
    title: 'Glute Bridges',
    subtitle: '3 sets • 10–15 reps',
    frontStoragePath: 'tutorial_videos/glutes/glute_bridges/front.mp4',
    sideStoragePath: 'tutorial_videos/glutes/glute_bridges/side.mp4',
    poseDetectType: PoseExerciseType.gluteBridge,
  ),
  TutorialExercise(
    id: 'good_mornings',
    muscle: MuscleId.glutes,
    title: 'Good Mornings',
    subtitle: '3 sets • 10–15 reps',
    frontStoragePath: 'tutorial_videos/glutes/good_mornings/front.mp4',
    sideStoragePath: 'tutorial_videos/glutes/good_mornings/side.mp4',
  ),
  TutorialExercise(
    id: 'hip_abduction',
    muscle: MuscleId.glutes,
    title: 'Hip Abduction',
    subtitle: '3 sets • 10–15 reps/side',
    frontStoragePath: 'tutorial_videos/glutes/hip_abduction/front.mp4',
    sideStoragePath: 'tutorial_videos/glutes/hip_abduction/side.mp4',
  ),
];

/// Full tutorial catalog for exercise pickers and search.
List<TutorialExercise> get allTutorialExercises =>
    List<TutorialExercise>.unmodifiable(_allExercises);

List<TutorialExercise> exercisesForMuscle(MuscleId muscle) {
  return _allExercises.where((e) => e.muscle == muscle).toList();
}

TutorialExercise? findExerciseById(String exerciseId) {
  for (final TutorialExercise exercise in _allExercises) {
    if (exercise.id == exerciseId) return exercise;
  }
  return null;
}

/// All Firebase Storage paths for tutorial videos (21 exercises × 2 angles).
List<String> get allTutorialVideoStoragePaths => [
      for (final exercise in _allExercises) ...[
        exercise.frontStoragePath,
        exercise.sideStoragePath,
      ],
    ];
