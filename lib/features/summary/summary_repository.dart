import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'summary_models.dart';

class SummaryRepository {
  SummaryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _weightCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('weightLog');

  CollectionReference<Map<String, dynamic>> _workoutCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('workoutLog');

  Future<SummaryData> load() async {
    final String? uid = _uid;
    if (uid == null) {
      return SummaryData(weights: <WeightLog>[], workouts: <WorkoutLog>[]);
    }

    final QuerySnapshot<Map<String, dynamic>> wSnap = await _weightCol(
      uid,
    ).orderBy('at').get();
    final QuerySnapshot<Map<String, dynamic>> oSnap = await _workoutCol(
      uid,
    ).orderBy('at').get();

    final List<WeightLog> weights = wSnap.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final Map<String, dynamic> m = d.data();
          final Timestamp? at = m['at'] as Timestamp?;
          final double? kg = (m['kg'] as num?)?.toDouble();
          if (at == null || kg == null) return null;
          return WeightLog(at: at.toDate(), kg: kg);
        })
        .whereType<WeightLog>()
        .toList();

    final List<WorkoutLog> workouts = oSnap.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final Map<String, dynamic> m = d.data();
          final Timestamp? at = m['at'] as Timestamp?;
          if (at == null) return null;
          return WorkoutLog(
            at: at.toDate(),
            sets: (m['sets'] as num?)?.toInt() ?? 0,
            title: m['title'] as String? ?? 'Workout',
          );
        })
        .whereType<WorkoutLog>()
        .toList();

    return SummaryData(weights: weights, workouts: workouts);
  }

  Future<void> logWeight(double kg) async {
    final String? uid = _uid;
    if (uid == null) return;
    final DateTime now = DateTime.now();
    final DateTime dayStart = DateTime(now.year, now.month, now.day);
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));

    final QuerySnapshot<Map<String, dynamic>> today = await _weightCol(uid)
        .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('at', isLessThan: Timestamp.fromDate(dayEnd))
        .limit(1)
        .get();

    final Map<String, dynamic> payload = <String, dynamic>{
      'at': Timestamp.fromDate(now),
      'kg': kg,
    };
    if (today.docs.isNotEmpty) {
      await today.docs.first.reference.update(payload);
    } else {
      await _weightCol(uid).add(payload);
    }
  }

  Future<void> logWorkout({required int sets, required String title}) async {
    final String? uid = _uid;
    if (uid == null) return;
    await _workoutCol(uid).add(<String, dynamic>{
      'at': Timestamp.fromDate(DateTime.now()),
      'sets': sets,
      'title': title,
    });
  }
}
