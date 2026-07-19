import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/workout_plan_models.dart';
import '../repositories/workout_plan_repository.dart';

class _CatalogEntry {
  const _CatalogEntry({
    required this.id,
    required this.title,
    required this.muscle,
    required this.defaultSets,
  });

  final String id;
  final String title;
  final String muscle;
  final String defaultSets;
}

const List<_CatalogEntry> _availableExercises = <_CatalogEntry>[
  _CatalogEntry(
    id: 'bench_dips_chair',
    title: 'Bench Dips (Chair)',
    muscle: 'arms',
    defaultSets: '3 × 8–12 reps',
  ),
  _CatalogEntry(
    id: 'diamond_knee_push_ups',
    title: 'Diamond Knee Push-ups',
    muscle: 'arms',
    defaultSets: '3 × 6–10 reps',
  ),
  _CatalogEntry(
    id: 'triceps_extensions',
    title: 'Triceps Extensions',
    muscle: 'arms',
    defaultSets: '3 × 6–10 reps',
  ),

  _CatalogEntry(
    id: 'push_ups',
    title: 'Push-ups',
    muscle: 'chest',
    defaultSets: '3 × 8–12 reps',
  ),
  _CatalogEntry(
    id: 'incline_push_ups',
    title: 'Incline Push-ups',
    muscle: 'chest',
    defaultSets: '3 × 8–15 reps',
  ),
  _CatalogEntry(
    id: 'decline_push_ups',
    title: 'Decline Push-ups',
    muscle: 'chest',
    defaultSets: '3 × 6–12 reps',
  ),

  _CatalogEntry(
    id: 'crunches',
    title: 'Crunches',
    muscle: 'abs',
    defaultSets: '3 × 12–20 reps',
  ),
  _CatalogEntry(
    id: 'laying_leg_raises',
    title: 'Laying Leg Raises',
    muscle: 'abs',
    defaultSets: '3 × 8–12 reps',
  ),
  _CatalogEntry(
    id: 'hand_plank',
    title: 'Hand Plank',
    muscle: 'abs',
    defaultSets: '3 × 30–60 sec',
  ),

  _CatalogEntry(
    id: 'bodyweight_squats',
    title: 'Bodyweight Squats',
    muscle: 'legs',
    defaultSets: '3 × 10–15 reps',
  ),
  _CatalogEntry(
    id: 'forward_lunges',
    title: 'Forward Lunges',
    muscle: 'legs',
    defaultSets: '3 × 8–12 reps/side',
  ),
  _CatalogEntry(
    id: 'bulgarian_split_squats',
    title: 'Bulgarian Split Squats',
    muscle: 'legs',
    defaultSets: '3 × 10–15 reps',
  ),

  _CatalogEntry(
    id: 'pike_push_ups',
    title: 'Pike Push-ups',
    muscle: 'shoulders',
    defaultSets: '3 × 6–10 reps',
  ),
  _CatalogEntry(
    id: 'forward_arm_circles',
    title: 'Forward Arm Circles',
    muscle: 'shoulders',
    defaultSets: '3 × 8–12 reps',
  ),
  _CatalogEntry(
    id: 'backward_arm_circle',
    title: 'Backward Arm Circle',
    muscle: 'shoulders',
    defaultSets: '3 × 8–12 reps',
  ),

  _CatalogEntry(
    id: 'plate_superman_hold',
    title: 'Plate Superman Hold',
    muscle: 'back',
    defaultSets: '3 × 20–40 sec',
  ),
  _CatalogEntry(
    id: 'superman',
    title: 'Superman',
    muscle: 'back',
    defaultSets: '3 × 10–15 reps',
  ),
  _CatalogEntry(
    id: 'superman_pull',
    title: 'Superman Pull',
    muscle: 'back',
    defaultSets: '3 × 8–12 reps',
  ),

  _CatalogEntry(
    id: 'glute_bridges',
    title: 'Glute Bridges',
    muscle: 'glutes',
    defaultSets: '3 × 10–15 reps',
  ),
  _CatalogEntry(
    id: 'good_mornings',
    title: 'Good Mornings',
    muscle: 'glutes',
    defaultSets: '3 × 10–15 reps',
  ),
  _CatalogEntry(
    id: 'hip_abduction',
    title: 'Hip Abduction',
    muscle: 'glutes',
    defaultSets: '3 × 10–15 reps/side',
  ),
];

typedef PlanAiCaller = Future<String> Function(String prompt);

class WorkoutPlanService {
  WorkoutPlanService({
    WorkoutPlanRepository? repository,
    FirebaseFirestore? firestore,
    this.aiCaller,
  }) : _repository = repository ?? WorkoutPlanRepository(),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final WorkoutPlanRepository _repository;
  final FirebaseFirestore _firestore;

  final PlanAiCaller? aiCaller;

  static const String _modelName = 'gemini-2.5-flash';

  static const int _kMaxWeeks = 4;

  Future<GeneratedPlan> generateAndSavePlan({String? userPrompt}) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw WorkoutPlanServiceException(
        'You must be signed in to generate a plan.',
      );
    }

    final (int weeks, bool exceededMonth) = _requestedWeeks(userPrompt);

    final Map<String, dynamic> profile = await _fetchProfile(uid);

    if (weeks <= 1) {
      final String prompt = _buildPrompt(
        profile: profile,
        userPrompt: userPrompt,
      );
      final String rawJson = await _callGemini(prompt);
      final WorkoutPlan plan = _parsePlan(uid: uid, rawJson: rawJson);
      final String planId = await _repository.savePlan(plan);
      return GeneratedPlan(
        plan: plan.copyWith(id: planId, createdAt: DateTime.now()),
        totalWeeks: 1,
        exceededMonth: false,
      );
    }

    final String prompt = _buildSeriesPrompt(
      profile: profile,
      userPrompt: userPrompt,
      weeks: weeks,
    );

    final String rawJson = await _callGemini(prompt, maxOutputTokens: 8192);
    final List<WorkoutPlan> weekPlans = _parseSeries(
      uid: uid,
      rawJson: rawJson,
      weeks: weeks,
    );
    final WorkoutPlan firstWeek = await _repository.saveSeries(weekPlans);
    return GeneratedPlan(
      plan: firstWeek,
      totalWeeks: weekPlans.length,
      exceededMonth: exceededMonth,
    );
  }

  (int, bool) _requestedWeeks(String? prompt) {
    if (prompt == null) return (1, false);
    final String t = prompt.toLowerCase();

    if (t.contains('year') || t.contains('quarter')) {
      return (_kMaxWeeks, true);
    }

    final RegExpMatch? mm = RegExp(r'(\d+)\s*months?').firstMatch(t);
    if (mm != null) {
      final int months = int.tryParse(mm.group(1) ?? '1') ?? 1;
      return (_kMaxWeeks, months >= 2);
    }

    if (t.contains('a month') ||
        t.contains('one month') ||
        t.contains('1 month') ||
        t.contains('this month') ||
        t.contains('monthly')) {
      return (_kMaxWeeks, false);
    }

    final RegExpMatch? wm = RegExp(r'(\d+)\s*weeks?').firstMatch(t);
    if (wm != null) {
      final int n = int.tryParse(wm.group(1) ?? '1') ?? 1;
      if (n > _kMaxWeeks) return (_kMaxWeeks, true);
      return (n < 1 ? 1 : n, false);
    }

    return (1, false);
  }

  Future<Map<String, dynamic>> _fetchProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    return doc.data() ?? <String, dynamic>{};
  }

  String _buildPrompt({
    required Map<String, dynamic> profile,
    String? userPrompt,
  }) {
    final String gender = (profile['gender'] as String?) ?? 'not specified';
    final dynamic age = profile['age'];
    final dynamic weight = profile['weight'];
    final dynamic height = profile['height'];
    final String activityLevel =
        (profile['activityLevel'] as String?) ?? 'moderate';
    final String goal = (profile['goal'] as String?) ?? 'general fitness';
    final String experience =
        (profile['experienceLevel'] as String?) ?? 'beginner';

    final StringBuffer catalogBuffer = StringBuffer();
    for (final _CatalogEntry e in _availableExercises) {
      catalogBuffer.writeln(
        '- id: "${e.id}" | title: "${e.title}" | muscle: ${e.muscle} | default sets: ${e.defaultSets}',
      );
    }

    return '''
You are a certified fitness coach creating a personalised home workout plan.

USER PROFILE:
- Gender: $gender
- Age: ${age ?? 'not specified'}
- Weight: ${weight != null ? '${weight}kg' : 'not specified'}
- Height: ${height != null ? '${height}cm' : 'not specified'}
- Activity level: $activityLevel
- Fitness goal: $goal
- Experience level: $experience
${userPrompt != null ? '- User request: "$userPrompt"' : ''}

AVAILABLE EXERCISES (you must ONLY use exercises from this list):
$catalogBuffer

INSTRUCTIONS:
1. Create a weekly workout plan (3–7 days depending on the user's activity level and request).
2. Each day should have 3–5 exercises chosen from the list above.
3. Vary muscle groups to avoid consecutive days working the same muscles.
4. Scale sets/reps to the user's experience level — keep it beginner-friendly unless stated otherwise.
5. Give the plan a short descriptive title (e.g. "Full Body Beginner · 4-Day Plan").

RESPONSE FORMAT:
Return ONLY a valid JSON object. No markdown, no explanation, no extra text.

{
  "title": "string",
  "days": [
    {
      "dayNumber": 1,
      "label": "Day 1 – Lower Body",
      "exercises": [
        {
          "exerciseId": "bodyweight_squats",
          "title": "Bodyweight Squats",
          "setsLabel": "3 × 10–15 reps"
        }
      ]
    }
  ]
}
''';
  }

  String _buildSeriesPrompt({
    required Map<String, dynamic> profile,
    String? userPrompt,
    required int weeks,
  }) {
    final String gender = (profile['gender'] as String?) ?? 'not specified';
    final dynamic age = profile['age'];
    final dynamic weight = profile['weight'];
    final dynamic height = profile['height'];
    final String activityLevel =
        (profile['activityLevel'] as String?) ?? 'moderate';
    final String goal = (profile['goal'] as String?) ?? 'general fitness';
    final String experience =
        (profile['experienceLevel'] as String?) ?? 'beginner';

    final StringBuffer catalogBuffer = StringBuffer();
    for (final _CatalogEntry e in _availableExercises) {
      catalogBuffer.writeln(
        '- id: "${e.id}" | title: "${e.title}" | muscle: ${e.muscle} | default sets: ${e.defaultSets}',
      );
    }

    return '''
MULTIWEEK_TASK
You are a certified fitness coach creating a personalised $weeks-week PROGRESSIVE home workout plan.

USER PROFILE:
- Gender: $gender
- Age: ${age ?? 'not specified'}
- Weight: ${weight != null ? '${weight}kg' : 'not specified'}
- Height: ${height != null ? '${height}cm' : 'not specified'}
- Activity level: $activityLevel
- Fitness goal: $goal
- Experience level: $experience
${userPrompt != null ? '- User request: "$userPrompt"' : ''}

AVAILABLE EXERCISES (you must ONLY use exercises from this list):
$catalogBuffer

INSTRUCTIONS:
1. Create EXACTLY $weeks weeks. Do NOT exceed $weeks weeks.
2. Make the weeks PROGRESSIVE: week 1 is the easiest (lower reps/sets or easier
   variations); each later week adds a little volume or harder variations so the
   user builds up over the month.
3. Each week has 3–5 workout days; each day has 3–5 exercises from the list.
4. Vary muscle groups so consecutive days don't work the same muscles.
5. Keep it beginner-friendly unless the user asked otherwise.
6. Give the whole plan one short descriptive title.

RESPONSE FORMAT:
Return ONLY a valid JSON object. No markdown, no explanation, no extra text.

{
  "title": "string",
  "weeks": [
    {
      "weekNumber": 1,
      "label": "Week 1 – Foundation",
      "days": [
        {
          "dayNumber": 1,
          "label": "Day 1 – Lower Body",
          "exercises": [
            {
              "exerciseId": "bodyweight_squats",
              "title": "Bodyweight Squats",
              "setsLabel": "3 × 10–15 reps"
            }
          ]
        }
      ]
    }
  ]
}
''';
  }

  Future<String> _callGemini(
    String prompt, {
    int maxOutputTokens = 2048,
  }) async {
    final PlanAiCaller? override = aiCaller;
    if (override != null) {
      return override(prompt);
    }
    try {
      final GenerativeModel model = FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          maxOutputTokens: maxOutputTokens,

          responseMimeType: 'application/json',

          thinkingConfig: ThinkingConfig.withThinkingBudget(0),
        ),
      );

      final GenerateContentResponse response = await model.generateContent(
        <Content>[Content.text(prompt)],
      );

      final String? text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw WorkoutPlanServiceException(
          'Gemini returned an empty response. Please try again.',
        );
      }
      final String trimmed = text.trim();
      debugPrint(
        'PLAN_AI_RAW len=${trimmed.length}: '
        '${trimmed.substring(0, trimmed.length < 600 ? trimmed.length : 600)}',
      );
      return trimmed;
    } on FirebaseException catch (e) {
      debugPrint('PLAN_AI_ERROR Firebase [${e.code}]: ${e.message}');
      throw WorkoutPlanServiceException(
        'Firebase AI error: ${e.message ?? 'Unknown error'}.',
      );
    } catch (e) {
      if (e is WorkoutPlanServiceException) rethrow;
      debugPrint('PLAN_AI_ERROR ${e.runtimeType}: $e');
      throw WorkoutPlanServiceException(
        'Could not reach the AI. Please check your connection and try again.',
      );
    }
  }

  WorkoutPlan _parsePlan({required String uid, required String rawJson}) {
    final String cleaned = rawJson
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    late Map<String, dynamic> json;
    try {
      json = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('PLAN_AI_PARSE_FAIL len=${cleaned.length}: $cleaned');
      throw WorkoutPlanServiceException(
        'Could not parse the AI response. Please try again.',
      );
    }

    final String title = json['title'] as String? ?? 'AI Workout Plan';
    final List<dynamic> rawDays = json['days'] as List<dynamic>? ?? <dynamic>[];

    final List<PlanDay> days = rawDays
        .whereType<Map<String, dynamic>>()
        .map(_parseDay)
        .toList();

    if (days.isEmpty) {
      debugPrint(
        'PLAN_AI_EMPTY (all days/exercises filtered) cleaned=$cleaned',
      );
      throw WorkoutPlanServiceException(
        'The AI generated an empty plan. Please try again.',
      );
    }

    return WorkoutPlan(
      id: '',
      userId: uid,
      title: title,
      status: WorkoutPlanStatus.draft,
      days: days,
      progress: PlanProgress(completedDays: 0, totalDays: days.length),
      createdAt: DateTime.now(),
    );
  }

  List<WorkoutPlan> _parseSeries({
    required String uid,
    required String rawJson,
    required int weeks,
  }) {
    final String cleaned = rawJson
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    late Map<String, dynamic> json;
    try {
      json = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('PLAN_AI_PARSE_FAIL(series) len=${cleaned.length}: $cleaned');
      throw WorkoutPlanServiceException(
        'Could not parse the AI response. Please try again.',
      );
    }

    final String title = json['title'] as String? ?? 'AI Workout Plan';
    final List<dynamic> rawWeeks =
        json['weeks'] as List<dynamic>? ?? <dynamic>[];

    final List<List<PlanDay>> weekDays = <List<PlanDay>>[];
    for (final Map<String, dynamic> w
        in rawWeeks.whereType<Map<String, dynamic>>()) {
      if (weekDays.length >= weeks) break;
      final List<dynamic> rawDays = w['days'] as List<dynamic>? ?? <dynamic>[];
      final List<PlanDay> days = rawDays
          .whereType<Map<String, dynamic>>()
          .map(_parseDay)
          .toList();
      if (days.isEmpty) continue;
      weekDays.add(days);
    }

    if (weekDays.isEmpty) {
      debugPrint('PLAN_AI_EMPTY(series) cleaned=$cleaned');
      throw WorkoutPlanServiceException(
        'The AI generated an empty plan. Please try again.',
      );
    }

    final int total = weekDays.length;
    final String seriesId = _repository.newPlanId();
    final DateTime now = DateTime.now();

    return List<WorkoutPlan>.generate(total, (int i) {
      final int weekNumber = i + 1;
      final List<PlanDay> days = weekDays[i];
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
  }

  PlanDay _parseDay(Map<String, dynamic> map) {
    final int dayNumber = (map['dayNumber'] as num?)?.toInt() ?? 0;
    final String label = map['label'] as String? ?? 'Day $dayNumber';
    final List<dynamic> rawExercises =
        map['exercises'] as List<dynamic>? ?? <dynamic>[];

    final List<PlanExercise> exercises = rawExercises
        .whereType<Map<String, dynamic>>()
        .map(_parseExercise)
        .where((PlanExercise e) => e.exerciseId.isNotEmpty)
        .toList();

    return PlanDay(dayNumber: dayNumber, label: label, exercises: exercises);
  }

  PlanExercise _parseExercise(Map<String, dynamic> map) {
    final String exerciseId = map['exerciseId'] as String? ?? '';
    final String title = map['title'] as String? ?? 'Exercise';
    final String setsLabel = map['setsLabel'] as String? ?? '3 sets';

    final bool valid = _availableExercises.any((e) => e.id == exerciseId);
    if (!valid) {
      return const PlanExercise(exerciseId: '', title: '', setsLabel: '');
    }

    return PlanExercise(
      exerciseId: exerciseId,
      title: title,
      setsLabel: setsLabel,
    );
  }
}

class GeneratedPlan {
  const GeneratedPlan({
    required this.plan,
    required this.totalWeeks,
    required this.exceededMonth,
  });

  final WorkoutPlan plan;
  final int totalWeeks;
  final bool exceededMonth;
}

class WorkoutPlanServiceException implements Exception {
  const WorkoutPlanServiceException(this.message);

  final String message;

  @override
  String toString() => 'WorkoutPlanServiceException: $message';
}
