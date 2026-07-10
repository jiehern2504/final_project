import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../summary/summary_repository.dart';
import 'widgets/activity_step.dart';
import 'widgets/gender_step.dart';
import 'widgets/intro_slide.dart';
import 'widgets/number_wheel.dart';
import 'widgets/onboarding_scaffold.dart';
import 'widgets/weight_ruler.dart';

/// First-run onboarding: an intro carousel followed by a profile wizard
/// (gender → age → weight → height → activity). On finish it writes the
/// physical stats to `users/{uid}`; [AuthPage] then routes on to the home page.
///
/// This is rendered by `AuthPage` while the signed-in user's profile stats are
/// still empty, so it also resumes correctly if the app is closed mid-way.
class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  static const int _introCount = 3;
  static const int _wizardSteps = 5;
  static const int _lastStep = _introCount + _wizardSteps - 1; // 7

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  int _step = 0;

  String _gender = 'male';
  int _age = 25;
  int _weight = 60;
  int _height = 170;
  String _activity = 'moderate';

  bool _saving = false;

  void _next() {
    if (_step < OnboardingFlowPage._lastStep) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    if (_saving) return;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        <String, dynamic>{
          'gender': _gender,
          'age': _age,
          'height': _height,
          'weight': _weight,
          'activityLevel': _activity,
          // Anchor for yearly age auto-increment (see AgeUpdater).
          'ageSetAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      // Seed the Home summary chart with the starting weight.
      await SummaryRepository().logWeight(_weight.toDouble());
      // AuthPage watches this document and will route to HomePage now that the
      // stats are filled — no manual navigation needed here.
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _buildStep(),
                ),
              ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return IntroSlide(
          index: 0,
          total: OnboardingFlowPage._introCount,
          title: 'Make Every Rep Count',
          subtitle: 'Your journey begins here',
          buttonLabel: 'Next',
          onNext: _next,
        );
      case 1:
        return IntroSlide(
          index: 1,
          total: OnboardingFlowPage._introCount,
          title: 'Build Your Workout Paradise',
          subtitle: 'Fuel, train, and grow',
          buttonLabel: 'Next',
          onNext: _next,
        );
      case 2:
        return IntroSlide(
          index: 2,
          total: OnboardingFlowPage._introCount,
          title: 'Embrace the Burn',
          subtitle: "Let's set up your profile",
          buttonLabel: 'Get started',
          onNext: _next,
        );
      case 3:
        return _wizard(
          title: 'Tell us about yourself',
          subtitle: 'This personalizes your plan',
          child: GenderStep(
            gender: _gender,
            onChanged: (String g) => setState(() => _gender = g),
          ),
        );
      case 4:
        return _wizard(
          title: 'How old are you?',
          subtitle: 'You can change this later',
          child: NumberWheel(
            min: 14,
            max: 80,
            value: _age,
            unit: 'yrs',
            onChanged: (int v) => setState(() => _age = v),
          ),
        );
      case 5:
        return _wizard(
          title: "What's your weight?",
          subtitle: 'Slide to adjust',
          child: WeightRuler(
            min: 35,
            max: 150,
            value: _weight,
            onChanged: (int v) => setState(() => _weight = v),
          ),
        );
      case 6:
        return _wizard(
          title: "What's your height?",
          subtitle: 'You can change this later',
          child: NumberWheel(
            min: 120,
            max: 220,
            value: _height,
            unit: 'cm',
            onChanged: (int v) => setState(() => _height = v),
          ),
        );
      default:
        return _wizard(
          title: 'Your activity level?',
          subtitle: 'How often do you train?',
          buttonLabel: 'Start',
          child: ActivityStep(
            activity: _activity,
            onChanged: (String a) => setState(() => _activity = a),
          ),
        );
    }
  }

  Widget _wizard({
    required String title,
    required String subtitle,
    required Widget child,
    String buttonLabel = 'Next',
  }) {
    return StepScaffold(
      stepIndex: _step - OnboardingFlowPage._introCount + 1,
      totalSteps: OnboardingFlowPage._wizardSteps,
      title: title,
      subtitle: subtitle,
      onBack: _back,
      buttonLabel: buttonLabel,
      onNext: _next,
      child: child,
    );
  }
}
