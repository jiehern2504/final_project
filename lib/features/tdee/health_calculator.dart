/// Pure calculation logic for the BMI / TDEE feature.
///
/// This file has NO Flutter/UI dependencies on purpose, so the formulas can be
/// unit-tested and maintained independently of the widgets that display them.
library;

/// Which calculator is currently shown.
enum CalcMode { bmi, tdee }

/// BMI health bands.
enum BmiLevel { underweight, normal, overweight, obese }

extension BmiLevelLabel on BmiLevel {
  String get label {
    switch (this) {
      case BmiLevel.underweight:
        return 'Underweight';
      case BmiLevel.normal:
        return 'Normal';
      case BmiLevel.overweight:
        return 'Overweight';
      case BmiLevel.obese:
        return 'Obese';
    }
  }
}

/// Activity level → TDEE multiplier (Mifflin-St Jeor). Keys match the values
/// stored in the user's Firestore `activityLevel` field.
const Map<String, double> kActivityFactors = <String, double>{
  'sedentary': 1.2,
  'light': 1.375,
  'moderate': 1.55,
  'active': 1.725,
};

/// Display labels for each activity level.
const Map<String, String> kActivityLabels = <String, String>{
  'sedentary': 'Sedentary',
  'light': 'Light',
  'moderate': 'Moderate',
  'active': 'Active',
};

/// Stateless helper holding the health formulas. All methods return `null` when
/// the inputs are missing or invalid, so the UI can show a placeholder.
abstract final class HealthCalculator {
  /// Body Mass Index = weight(kg) / height(m)². [height] is in centimetres.
  static double? bmi({double? height, double? weight}) {
    if (height == null || weight == null || height <= 0 || weight <= 0) {
      return null;
    }
    final double metres = height / 100.0;
    return weight / (metres * metres);
  }

  /// Basal Metabolic Rate (Mifflin-St Jeor). [gender] is 'male' or 'female'.
  static double? bmr({
    required String gender,
    double? age,
    double? height,
    double? weight,
  }) {
    if (age == null ||
        height == null ||
        weight == null ||
        age <= 0 ||
        height <= 0 ||
        weight <= 0) {
      return null;
    }
    final double base = 10 * weight + 6.25 * height - 5 * age;
    return gender == 'female' ? base - 161 : base + 5;
  }

  /// Total Daily Energy Expenditure = BMR × activity factor.
  static double? tdee({
    required String gender,
    required String activity,
    double? age,
    double? height,
    double? weight,
  }) {
    final double? base = bmr(
      gender: gender,
      age: age,
      height: height,
      weight: weight,
    );
    if (base == null) return null;
    return base * (kActivityFactors[activity] ?? 1.55);
  }

  /// Classifies a BMI value into a [BmiLevel], or `null` if [bmi] is null.
  static BmiLevel? categorize(double? bmi) {
    if (bmi == null) return null;
    if (bmi < 18.5) return BmiLevel.underweight;
    if (bmi < 25) return BmiLevel.normal;
    if (bmi < 30) return BmiLevel.overweight;
    return BmiLevel.obese;
  }
}

/// Formats a calorie value with a thousands separator, e.g. 2180 → "2,180".
String formatCalories(double value) {
  final String digits = value.round().toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
