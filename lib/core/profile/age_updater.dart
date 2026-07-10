import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Keeps the user's stored `age` current.
///
/// The profile stores `age` as a plain number (no birth date), so we also store
/// `ageSetAt` — the moment the age was last set/confirmed. On each app start we
/// check how many whole years have passed and bump `age` accordingly, moving the
/// anchor forward so it stays accurate. Existing users (no `ageSetAt`) simply
/// start counting from now, so nothing is ever added out of thin air.
class AgeUpdater {
  const AgeUpdater._();

  /// Minimum/maximum age kept in sync with the profile form validation.
  static const int _minAge = 12;
  static const int _maxAge = 100;

  static Future<void> maybeAdvance() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final DocumentReference<Map<String, dynamic>> ref =
        FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
      final Map<String, dynamic>? data = snap.data();
      if (data == null) return;

      final int? age = (data['age'] as num?)?.toInt();
      if (age == null) return;

      final Timestamp? setAt = data['ageSetAt'] as Timestamp?;
      if (setAt == null) {
        // Backfill: begin counting from now, no increment.
        await ref.set(
          <String, dynamic>{'ageSetAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        return;
      }

      final DateTime anchor = setAt.toDate();
      final int years = _fullYearsBetween(anchor, DateTime.now());
      if (years >= 1 && age < _maxAge) {
        final int newAge = (age + years).clamp(_minAge, _maxAge);
        // Move the anchor forward by the years we just counted.
        final DateTime newAnchor =
            DateTime(anchor.year + years, anchor.month, anchor.day);
        await ref.set(
          <String, dynamic>{
            'age': newAge,
            'ageSetAt': Timestamp.fromDate(newAnchor),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // Non-fatal — never block app start on this.
    }
  }

  /// Whole years elapsed from [from] to [to] (0 if the anniversary hasn't come).
  static int _fullYearsBetween(DateTime from, DateTime to) {
    int years = to.year - from.year;
    final DateTime anniversary = DateTime(to.year, from.month, from.day);
    if (to.isBefore(anniversary)) years -= 1;
    return years < 0 ? 0 : years;
  }
}
