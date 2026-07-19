import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'health_calculator.dart';
import 'widgets/calc_mode_switch.dart';
import 'widgets/gender_toggle.dart';
import 'widgets/input_card.dart';
import 'widgets/result_card.dart';

class TdeeBmiPage extends StatefulWidget {
  const TdeeBmiPage({super.key});

  @override
  State<TdeeBmiPage> createState() => _TdeeBmiPageState();
}

class _TdeeBmiPageState extends State<TdeeBmiPage> {
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  CalcMode _mode = CalcMode.bmi;
  String _gender = 'male';
  String _activity = 'moderate';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in <TextEditingController>[
      _ageController,
      _heightController,
      _weightController,
    ]) {
      c.addListener(() => setState(() {}));
    }
    _loadProfile();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(uid)
          .get();
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        final Object? age = data['age'];
        final Object? height = data['height'];
        final Object? weight = data['weight'];
        if (age != null) _ageController.text = _trimNumber(age);
        if (height != null) _heightController.text = _trimNumber(height);
        if (weight != null) _weightController.text = _trimNumber(weight);
        _gender = data['gender'] == 'female' ? 'female' : 'male';
        final String activity =
            (data['activityLevel'] as String?) ?? 'moderate';
        _activity = kActivityFactors.containsKey(activity)
            ? activity
            : 'moderate';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _trimNumber(Object value) {
    final double? d = double.tryParse(value.toString());
    if (d == null) return value.toString();
    return d == d.roundToDouble() ? d.round().toString() : d.toString();
  }

  double? get _age => double.tryParse(_ageController.text.trim());
  double? get _height => double.tryParse(_heightController.text.trim());
  double? get _weight => double.tryParse(_weightController.text.trim());

  @override
  Widget build(BuildContext context) {
    final double? bmr = HealthCalculator.bmr(
      gender: _gender,
      age: _age,
      height: _height,
      weight: _weight,
    );
    final double? tdee = HealthCalculator.tdee(
      gender: _gender,
      activity: _activity,
      age: _age,
      height: _height,
      weight: _weight,
    );
    final double? bmi = HealthCalculator.bmi(height: _height, weight: _weight);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: CalcModeSwitch(
          mode: _mode,
          onChanged: (m) => setState(() => _mode = m),
        ),
        actions: [
          GenderToggle(
            gender: _gender,
            onChanged: (g) => setState(() => _gender = g),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        ResultCard(mode: _mode, bmi: bmi, bmr: bmr, tdee: tdee),
                        const SizedBox(height: 14),
                        InputCard(
                          mode: _mode,
                          ageController: _ageController,
                          heightController: _heightController,
                          weightController: _weightController,
                          activity: _activity,
                          onActivityChanged: (a) =>
                              setState(() => _activity = a),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => FocusScope.of(context).unfocus(),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Calculate',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
