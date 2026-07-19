import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AgeUpdater {
  const AgeUpdater._();

  static const int _minAge = 12;
  static const int _maxAge = 100;

  static Future<void> maybeAdvance() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final DocumentReference<Map<String, dynamic>> ref = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid);
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
      final Map<String, dynamic>? data = snap.data();
      if (data == null) return;

      final int? age = (data['age'] as num?)?.toInt();
      if (age == null) return;

      final Timestamp? setAt = data['ageSetAt'] as Timestamp?;
      if (setAt == null) {
        await ref.set(<String, dynamic>{
          'ageSetAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      final DateTime anchor = setAt.toDate();
      final int years = _fullYearsBetween(anchor, DateTime.now());
      if (years >= 1 && age < _maxAge) {
        final int newAge = (age + years).clamp(_minAge, _maxAge);

        final DateTime newAnchor = DateTime(
          anchor.year + years,
          anchor.month,
          anchor.day,
        );
        await ref.set(<String, dynamic>{
          'age': newAge,
          'ageSetAt': Timestamp.fromDate(newAnchor),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  static int _fullYearsBetween(DateTime from, DateTime to) {
    int years = to.year - from.year;
    final DateTime anniversary = DateTime(to.year, from.month, from.day);
    if (to.isBefore(anniversary)) years -= 1;
    return years < 0 ? 0 : years;
  }
}
