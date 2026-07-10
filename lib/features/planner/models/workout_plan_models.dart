import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkoutPlanStatus { draft, active, completed }

WorkoutPlanStatus workoutPlanStatusFromString(String? raw) {
  switch (raw) {
    case 'active':
      return WorkoutPlanStatus.active;
    case 'completed':
      return WorkoutPlanStatus.completed;
    default:
      return WorkoutPlanStatus.draft;
  }
}

String workoutPlanStatusToString(WorkoutPlanStatus status) {
  switch (status) {
    case WorkoutPlanStatus.active:
      return 'active';
    case WorkoutPlanStatus.completed:
      return 'completed';
    case WorkoutPlanStatus.draft:
      return 'draft';
  }
}

class PlanExercise {
  const PlanExercise({
    required this.exerciseId,
    required this.title,
    required this.setsLabel,
  });

  final String exerciseId;
  final String title;
  final String setsLabel;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'exerciseId': exerciseId,
        'title': title,
        'setsLabel': setsLabel,
      };

  factory PlanExercise.fromMap(Map<String, dynamic> map) {
    return PlanExercise(
      exerciseId: map['exerciseId'] as String? ?? '',
      title: map['title'] as String? ?? 'Exercise',
      setsLabel: map['setsLabel'] as String? ?? '3 sets',
    );
  }
}

class PlanDay {
  const PlanDay({
    required this.dayNumber,
    required this.label,
    required this.exercises,
    this.completed = false,
    this.isRest = false,
  });

  final int dayNumber;
  final String label;
  final List<PlanExercise> exercises;
  final bool completed;

  /// A rest day has no exercises — the user just marks it done.
  final bool isRest;

  PlanDay copyWith({bool? completed, bool? isRest}) {
    return PlanDay(
      dayNumber: dayNumber,
      label: label,
      exercises: exercises,
      completed: completed ?? this.completed,
      isRest: isRest ?? this.isRest,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'dayNumber': dayNumber,
        'label': label,
        'completed': completed,
        'isRest': isRest,
        'exercises': exercises.map((PlanExercise e) => e.toMap()).toList(),
      };

  factory PlanDay.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawExercises =
        map['exercises'] as List<dynamic>? ?? <dynamic>[];
    return PlanDay(
      dayNumber: (map['dayNumber'] as num?)?.toInt() ?? 0,
      label: map['label'] as String? ?? 'Day',
      completed: map['completed'] as bool? ?? false,
      isRest: map['isRest'] as bool? ?? false,
      exercises: rawExercises
          .whereType<Map<String, dynamic>>()
          .map(PlanExercise.fromMap)
          .toList(),
    );
  }
}

class PlanProgress {
  const PlanProgress({
    required this.completedDays,
    required this.totalDays,
  });

  final int completedDays;
  final int totalDays;

  double get fraction =>
      totalDays <= 0 ? 0 : (completedDays / totalDays).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() => <String, dynamic>{
        'completedDays': completedDays,
        'totalDays': totalDays,
      };

  factory PlanProgress.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const PlanProgress(completedDays: 0, totalDays: 0);
    }
    return PlanProgress(
      completedDays: (map['completedDays'] as num?)?.toInt() ?? 0,
      totalDays: (map['totalDays'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.status,
    required this.days,
    required this.progress,
    this.startedAt,
    this.createdAt,
    this.seriesId,
    this.weekNumber = 1,
    this.totalWeeks = 1,
    this.locked = false,
  });

  final String id;
  final String userId;
  final String title;
  final WorkoutPlanStatus status;
  final List<PlanDay> days;
  final PlanProgress progress;
  final DateTime? startedAt;
  final DateTime? createdAt;

  /// Links the weeks of a multi-week plan. Null for standalone (single-week)
  /// plans. All weeks of the same month share one [seriesId].
  final String? seriesId;

  /// 1-based position of this week within its series (1 for single-week plans).
  final int weekNumber;

  /// How many weeks the whole series has (1 for single-week plans).
  final int totalWeeks;

  /// A locked week is not yet available — it stays hidden until the previous
  /// week is completed and the user chooses to start it.
  final bool locked;

  /// True when this plan is one week of a multi-week series.
  bool get isSeries => totalWeeks > 1 && seriesId != null;

  bool get isStarted => status == WorkoutPlanStatus.active;

  WorkoutPlan copyWith({
    String? id,
    WorkoutPlanStatus? status,
    List<PlanDay>? days,
    PlanProgress? progress,
    DateTime? startedAt,
    DateTime? createdAt,
    bool? locked,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      userId: userId,
      title: title,
      status: status ?? this.status,
      days: days ?? this.days,
      progress: progress ?? this.progress,
      startedAt: startedAt ?? this.startedAt,
      createdAt: createdAt ?? this.createdAt,
      seriesId: seriesId,
      weekNumber: weekNumber,
      totalWeeks: totalWeeks,
      locked: locked ?? this.locked,
    );
  }

  PlanDay? dayByNumber(int dayNumber) {
    for (final PlanDay day in days) {
      if (day.dayNumber == dayNumber) return day;
    }
    return null;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'userId': userId,
        'title': title,
        'status': workoutPlanStatusToString(status),
        'days': days.map((PlanDay d) => d.toMap()).toList(),
        'progress': progress.toMap(),
        'weekNumber': weekNumber,
        'totalWeeks': totalWeeks,
        'locked': locked,
        if (seriesId != null) 'seriesId': seriesId,
        if (startedAt != null)
          'startedAt': Timestamp.fromDate(startedAt!),
        if (createdAt != null)
          'createdAt': Timestamp.fromDate(createdAt!),
      };

  factory WorkoutPlan.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final List<dynamic> rawDays =
        data['days'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic>? progressMap =
        data['progress'] as Map<String, dynamic>?;

    return WorkoutPlan(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Workout Plan',
      status: workoutPlanStatusFromString(data['status'] as String?),
      days: rawDays
          .whereType<Map<String, dynamic>>()
          .map(PlanDay.fromMap)
          .toList(),
      progress: PlanProgress.fromMap(progressMap),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      seriesId: data['seriesId'] as String?,
      weekNumber: (data['weekNumber'] as num?)?.toInt() ?? 1,
      totalWeeks: (data['totalWeeks'] as num?)?.toInt() ?? 1,
      locked: data['locked'] as bool? ?? false,
    );
  }
}
