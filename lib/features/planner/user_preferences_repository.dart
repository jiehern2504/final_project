import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WorkoutReminderPrefs {
  const WorkoutReminderPrefs({
    this.enabled = false,
    this.hour,
    this.minute,
  });

  final bool enabled;
  final int? hour;
  final int? minute;

  bool get hasTime => hour != null && minute != null;

  String formatTime() {
    if (!hasTime) return 'Not set';
    final int h = hour!;
    final int m = minute!;
    final String period = h >= 12 ? 'PM' : 'AM';
    final int displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayHour:${m.toString().padLeft(2, '0')} $period';
  }

  static WorkoutReminderPrefs fromMap(Map<String, dynamic>? data) {
    if (data == null) return const WorkoutReminderPrefs();
    return WorkoutReminderPrefs(
      enabled: data['workoutReminderEnabled'] as bool? ?? false,
      hour: (data['workoutReminderHour'] as num?)?.toInt(),
      minute: (data['workoutReminderMinute'] as num?)?.toInt(),
    );
  }
}

class UserPreferencesRepository {
  UserPreferencesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final String? uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  Stream<WorkoutReminderPrefs> watchWorkoutReminder() {
    final DocumentReference<Map<String, dynamic>>? doc = _userDoc;
    if (doc == null) {
      return Stream<WorkoutReminderPrefs>.value(const WorkoutReminderPrefs());
    }
    return doc.snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
          WorkoutReminderPrefs.fromMap(snapshot.data()),
    );
  }

  Future<WorkoutReminderPrefs> fetchWorkoutReminder() async {
    final DocumentReference<Map<String, dynamic>>? doc = _userDoc;
    if (doc == null) return const WorkoutReminderPrefs();
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await doc.get();
    return WorkoutReminderPrefs.fromMap(snapshot.data());
  }

  Future<void> saveWorkoutReminder({
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    final DocumentReference<Map<String, dynamic>>? doc = _userDoc;
    if (doc == null) {
      throw StateError('You must be signed in to save preferences.');
    }
    await doc.set(
      <String, dynamic>{
        'workoutReminderEnabled': enabled,
        'workoutReminderHour': hour ?? FieldValue.delete(),
        'workoutReminderMinute': minute ?? FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
  }
}
