library;

enum CalcMode { bmi, tdee }

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

const Map<String, double> kActivityFactors = <String, double>{
  'sedentary': 1.2,
  'light': 1.375,
  'moderate': 1.55,
  'active': 1.725,
};

const Map<String, String> kActivityLabels = <String, String>{
  'sedentary': 'Sedentary',
  'light': 'Light',
  'moderate': 'Moderate',
  'active': 'Active',
};

abstract final class HealthCalculator {
  static double? bmi({double? height, double? weight}) {
    if (height == null || weight == null || height <= 0 || weight <= 0) {
      return null;
    }
    final double metres = height / 100.0;
    return weight / (metres * metres);
  }

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

  static BmiLevel? categorize(double? bmi) {
    if (bmi == null) return null;
    if (bmi < 18.5) return BmiLevel.underweight;
    if (bmi < 25) return BmiLevel.normal;
    if (bmi < 30) return BmiLevel.overweight;
    return BmiLevel.obese;
  }
}

String formatCalories(double value) {
  final String digits = value.round().toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
