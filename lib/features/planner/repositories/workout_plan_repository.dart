import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../plan_generator.dart';
import '../models/workout_plan_models.dart';
import '../../summary/summary_repository.dart';

class WorkoutPlanRepository {
  WorkoutPlanRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _plans =>
      _firestore.collection('workout_plans');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Active plan, or latest draft if the user has not started yet.
  Stream<WorkoutPlan?> watchCurrentPlan() {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<WorkoutPlan?>.value(null);
    }
    return _plans.where('userId', isEqualTo: uid).snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<WorkoutPlan> plans = snapshot.docs
            .map(WorkoutPlan.fromFirestore)
            .toList();
        final List<WorkoutPlan> active = plans
            .where((WorkoutPlan p) => p.status == WorkoutPlanStatus.active)
            .toList();
        if (active.isNotEmpty) {
          return _latestFromPlans(active);
        }
        final List<WorkoutPlan> drafts = plans
            .where((WorkoutPlan p) => p.status == WorkoutPlanStatus.draft)
            .toList();
        if (drafts.isNotEmpty) {
          return _latestFromPlans(drafts);
        }
        return null;
      },
    );
  }

  Stream<WorkoutPlan?> watchActivePlan() {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<WorkoutPlan?>.value(null);
    }
    return _plans
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      return _latestFromDocs(snapshot.docs);
    });
  }

  Future<WorkoutPlan?> fetchActivePlan() async {
    final String? uid = _uid;
    if (uid == null) return null;
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _plans
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();
    return _latestFromDocs(snapshot.docs);
  }

  Future<WorkoutPlan?> fetchLatestPlan() async {
    final String? uid = _uid;
    if (uid == null) return null;
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _plans.where('userId', isEqualTo: uid).get();
    return _latestFromDocs(snapshot.docs);
  }

  WorkoutPlan? _latestFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return null;
    return _latestFromPlans(docs.map(WorkoutPlan.fromFirestore).toList());
  }

  WorkoutPlan? _latestFromPlans(List<WorkoutPlan> input) {
    // Locked weeks of a multi-week series are hidden until unlocked.
    final List<WorkoutPlan> plans =
        input.where((WorkoutPlan p) => !p.locked).toList();
    if (plans.isEmpty) return null;
    plans.sort((WorkoutPlan a, WorkoutPlan b) {
      final DateTime aTime =
          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bTime =
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return plans.first;
  }

  Future<String> savePlan(WorkoutPlan plan) async {
    final Map<String, dynamic> data = plan.toMap();
    if (plan.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      final DocumentReference<Map<String, dynamic>> ref =
          await _plans.add(data);
      return ref.id;
    }
    await _plans.doc(plan.id).set(data, SetOptions(merge: true));
    return plan.id;
  }

  /// A fresh Firestore document id, used to tag all weeks of one series before
  /// any of them are saved.
  String newPlanId() => _plans.doc().id;

  /// Saves every week of a multi-week series and returns the hydrated Week 1
  /// plan (the only unlocked week the user can start).
  Future<WorkoutPlan> saveSeries(
    List<WorkoutPlan> weeks, {
    String source = 'ai',
  }) async {
    WorkoutPlan? firstWeek;
    for (final WorkoutPlan week in weeks) {
      final Map<String, dynamic> data = week.toMap();
      data['source'] = source;
      data['createdAt'] = FieldValue.serverTimestamp();
      final DocumentReference<Map<String, dynamic>> ref = await _plans.add(data);
      if (week.weekNumber == 1) {
        firstWeek = week.copyWith(id: ref.id, createdAt: DateTime.now());
      }
    }
    if (firstWeek == null) {
      throw StateError('Series is missing Week 1.');
    }
    return firstWeek;
  }

  /// Saves a hand-built multi-week plan (one [PlanDay] list per week) as a
  /// locked series: Week 1 is a draft the user can start, later weeks unlock as
  /// each week is completed.
  Future<WorkoutPlan> saveManualSeries({
    required String title,
    required List<List<PlanDay>> weeks,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('You must be signed in to save a plan.');
    }
    final String seriesId = newPlanId();
    final int total = weeks.length;
    final DateTime now = DateTime.now();

    final List<WorkoutPlan> weekPlans = List<WorkoutPlan>.generate(total, (int i) {
      final int weekNumber = i + 1;
      final List<PlanDay> days = weeks[i];
      return WorkoutPlan(
        id: '',
        userId: uid,
        title: title,
        status: WorkoutPlanStatus.draft,
        days: days,
        progress: PlanProgress(completedDays: 0, totalDays: days.length),
        createdAt: now,
        seriesId: seriesId,
        weekNumber: weekNumber,
        totalWeeks: total,
        locked: weekNumber > 1,
      );
    });

    return saveSeries(weekPlans, source: 'manual');
  }

  /// Completes [current] and unlocks/activates the next week in the same series
  /// (if any). Called when the user finishes a week and chooses to continue.
  Future<void> advanceToNextWeek(WorkoutPlan current) async {
    final String? uid = _uid;
    final String? seriesId = current.seriesId;
    if (uid == null || seriesId == null) return;

    // Single-field query (no composite index needed); filter the series client
    // side to find the next week.
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _plans.where('userId', isEqualTo: uid).get();
    QueryDocumentSnapshot<Map<String, dynamic>>? nextDoc;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final int week = (data['weekNumber'] as num?)?.toInt() ?? 0;
      if (data['seriesId'] == seriesId && week == current.weekNumber + 1) {
        nextDoc = doc;
        break;
      }
    }

    final WriteBatch batch = _firestore.batch();
    batch.update(_plans.doc(current.id), <String, dynamic>{
      'status': 'completed',
    });
    if (nextDoc != null) {
      batch.update(nextDoc.reference, <String, dynamic>{
        'locked': false,
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> startPlan(String planId) async {
    final String? uid = _uid;
    if (uid == null) return;

    final QuerySnapshot<Map<String, dynamic>> activePlans = await _plans
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();

    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in activePlans.docs) {
      if (doc.id != planId) {
        batch.update(doc.reference, <String, dynamic>{
          'status': 'completed',
        });
      }
    }
    batch.update(_plans.doc(planId), <String, dynamic>{
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> markDayComplete(String planId, int dayNumber) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _plans.doc(planId).get();
    if (!doc.exists) return;

    final WorkoutPlan plan = WorkoutPlan.fromFirestore(doc);
    final List<PlanDay> updatedDays = plan.days.map((PlanDay day) {
      if (day.dayNumber == dayNumber) {
        return day.copyWith(completed: true);
      }
      return day;
    }).toList();

    final int completedDays =
        updatedDays.where((PlanDay d) => d.completed).length;
    final int totalDays = updatedDays.length;

    // Keep the plan 'active' even at 100% so the progress page can ASK the user
    // what to do next (repeat it or start a new plan) instead of silently
    // archiving it, which looked like an auto-reset.
    await _plans.doc(planId).update(<String, dynamic>{
      'days': updatedDays.map((PlanDay d) => d.toMap()).toList(),
      'progress': PlanProgress(
        completedDays: completedDays,
        totalDays: totalDays,
      ).toMap(),
      // Record when this happened so the UI can enforce "one day per day".
      // Client time (not serverTimestamp) so the local write immediately
      // reflects "marked today" — avoids a race where the next day briefly
      // looks markable before the server timestamp lands.
      'lastMarkedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Log the completed workout for the Home summary chart (skip rest days).
    final PlanDay? marked = plan.dayByNumber(dayNumber);
    if (marked != null && !marked.isRest && marked.exercises.isNotEmpty) {
      int sets = 0;
      for (final PlanExercise e in marked.exercises) {
        sets += _firstIntOf(e.setsLabel, fallback: 3);
      }
      await SummaryRepository(firestore: _firestore)
          .logWorkout(sets: sets, title: plan.title);
    }
  }

  /// First integer found in [s] (the "3" in "3 sets × 12 reps"); [fallback]
  /// when none is present.
  int _firstIntOf(String s, {int fallback = 0}) {
    final Match? m = RegExp(r'\d+').firstMatch(s);
    return m == null ? fallback : int.parse(m.group(0)!);
  }

  /// Resets all completed days back to zero and reactivates the plan. Because
  /// achievements/badges are derived from `progress.completedDays`, this also
  /// effectively resets them.
  Future<void> resetPlanProgress(String planId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _plans.doc(planId).get();
    if (!doc.exists) return;

    final WorkoutPlan plan = WorkoutPlan.fromFirestore(doc);
    final List<PlanDay> resetDays = plan.days
        .map((PlanDay day) => day.copyWith(completed: false))
        .toList();

    await _plans.doc(planId).update(<String, dynamic>{
      'days': resetDays.map((PlanDay d) => d.toMap()).toList(),
      'progress': PlanProgress(
        completedDays: 0,
        totalDays: resetDays.length,
      ).toMap(),
      'status': 'active',
      // Clear the daily lock so the user can start marking again today.
      'lastMarkedAt': FieldValue.delete(),
    });
  }

  /// Updates just the user's weight and height (kg / cm) on their profile.
  Future<void> updateBodyMetrics({
    required double weight,
    required double height,
  }) async {
    final String? uid = _uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set(
      <String, dynamic>{'weight': weight, 'height': height},
      SetOptions(merge: true),
    );
    // Record the weight so the Home summary chart has a data point.
    await SummaryRepository(firestore: _firestore).logWeight(weight);
  }

  /// Archives a plan (marks it 'completed') so it leaves the active slot and a
  /// new plan can take over. Keeps it in history rather than deleting it.
  Future<void> archivePlan(String planId) async {
    await _plans.doc(planId).update(<String, dynamic>{'status': 'completed'});
  }

  /// Permanently deletes a plan document (and therefore its progress).
  Future<void> deletePlan(String planId) async {
    await _plans.doc(planId).delete();
  }

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final String? uid = _uid;
    if (uid == null) return null;
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<String> saveManualPlan({
    required String title,
    required List<PlanDay> days,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('You must be signed in to save a plan.');
    }

    final WorkoutPlan draft = WorkoutPlan(
      id: '',
      userId: uid,
      title: title,
      status: WorkoutPlanStatus.draft,
      days: days,
      progress: PlanProgress(
        completedDays: 0,
        totalDays: days.length,
      ),
      createdAt: DateTime.now(),
    );

    final Map<String, dynamic> data = draft.toMap();
    data['source'] = 'manual';
    data['createdAt'] = FieldValue.serverTimestamp();
    final DocumentReference<Map<String, dynamic>> ref =
        await _plans.add(data);
    return ref.id;
  }

  Future<WorkoutPlan> generateAndSavePlan({
    required Map<String, dynamic> profile,
    String? userPrompt,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('You must be signed in to generate a plan.');
    }

    final WorkoutPlan draft = PlanGenerator.buildPlan(
      userId: uid,
      profile: profile,
      userPrompt: userPrompt,
    );

    final String planId = await savePlan(draft);
    return WorkoutPlan(
      id: planId,
      userId: draft.userId,
      title: draft.title,
      status: draft.status,
      days: draft.days,
      progress: draft.progress,
      createdAt: DateTime.now(),
    );
  }
}
