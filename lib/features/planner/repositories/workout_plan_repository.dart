import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../plan_generator.dart';
import '../models/workout_plan_models.dart';

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

  WorkoutPlan? _latestFromPlans(List<WorkoutPlan> plans) {
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
    final bool allDone =
        totalDays > 0 && completedDays >= totalDays;

    await _plans.doc(planId).update(<String, dynamic>{
      'days': updatedDays.map((PlanDay d) => d.toMap()).toList(),
      'progress': PlanProgress(
        completedDays: completedDays,
        totalDays: totalDays,
      ).toMap(),
      if (allDone) 'status': 'completed',
    });
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
