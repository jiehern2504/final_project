import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/workout_plan_models.dart';
import '../repositories/workout_plan_repository.dart';

// ── Exercise catalogue entry (lightweight, for prompt building) ────────────

/// A minimal representation of an available exercise used when building
/// the Gemini prompt. Keeps the service decoupled from [TutorialExercise].
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

/// The full catalogue of exercises available in this app.
///
/// Gemini will only schedule exercises from this list, which ensures that
/// every generated plan maps to a real tutorial video the user can watch.
const List<_CatalogEntry> _availableExercises = <_CatalogEntry>[
  // Arms
  _CatalogEntry(id: 'bench_dips_chair',      title: 'Bench Dips (Chair)',       muscle: 'arms',      defaultSets: '3 × 8–12 reps'),
  _CatalogEntry(id: 'diamond_knee_push_ups', title: 'Diamond Knee Push-ups',    muscle: 'arms',      defaultSets: '3 × 6–10 reps'),
  _CatalogEntry(id: 'triceps_extensions',    title: 'Triceps Extensions',       muscle: 'arms',      defaultSets: '3 × 6–10 reps'),
  // Chest
  _CatalogEntry(id: 'push_ups',             title: 'Push-ups',                 muscle: 'chest',     defaultSets: '3 × 8–12 reps'),
  _CatalogEntry(id: 'incline_push_ups',     title: 'Incline Push-ups',         muscle: 'chest',     defaultSets: '3 × 8–15 reps'),
  _CatalogEntry(id: 'decline_push_ups',     title: 'Decline Push-ups',         muscle: 'chest',     defaultSets: '3 × 6–12 reps'),
  // Abs
  _CatalogEntry(id: 'crunches',            title: 'Crunches',                  muscle: 'abs',       defaultSets: '3 × 12–20 reps'),
  _CatalogEntry(id: 'laying_leg_raises',   title: 'Laying Leg Raises',         muscle: 'abs',       defaultSets: '3 × 8–12 reps'),
  _CatalogEntry(id: 'hand_plank',          title: 'Hand Plank',                muscle: 'abs',       defaultSets: '3 × 30–60 sec'),
  // Legs
  _CatalogEntry(id: 'bodyweight_squats',   title: 'Bodyweight Squats',         muscle: 'legs',      defaultSets: '3 × 10–15 reps'),
  _CatalogEntry(id: 'forward_lunges',      title: 'Forward Lunges',            muscle: 'legs',      defaultSets: '3 × 8–12 reps/side'),
  _CatalogEntry(id: 'bulgarian_split_squats', title: 'Bulgarian Split Squats', muscle: 'legs',      defaultSets: '3 × 10–15 reps'),
  // Shoulders
  _CatalogEntry(id: 'pike_push_ups',           title: 'Pike Push-ups',         muscle: 'shoulders', defaultSets: '3 × 6–10 reps'),
  _CatalogEntry(id: 'forward_arm_circles',     title: 'Forward Arm Circles',   muscle: 'shoulders', defaultSets: '3 × 8–12 reps'),
  _CatalogEntry(id: 'backward_arm_circle',     title: 'Backward Arm Circle',   muscle: 'shoulders', defaultSets: '3 × 8–12 reps'),
  // Back
  _CatalogEntry(id: 'plate_superman_hold', title: 'Plate Superman Hold',       muscle: 'back',      defaultSets: '3 × 20–40 sec'),
  _CatalogEntry(id: 'superman',            title: 'Superman',                  muscle: 'back',      defaultSets: '3 × 10–15 reps'),
  _CatalogEntry(id: 'superman_pull',       title: 'Superman Pull',             muscle: 'back',      defaultSets: '3 × 8–12 reps'),
  // Glutes
  _CatalogEntry(id: 'glute_bridges',      title: 'Glute Bridges',             muscle: 'glutes',    defaultSets: '3 × 10–15 reps'),
  _CatalogEntry(id: 'good_mornings',      title: 'Good Mornings',             muscle: 'glutes',    defaultSets: '3 × 10–15 reps'),
  _CatalogEntry(id: 'hip_abduction',      title: 'Hip Abduction',             muscle: 'glutes',    defaultSets: '3 × 10–15 reps/side'),
];

// ── Service ────────────────────────────────────────────────────────────────

/// Generates a personalised weekly workout plan using Gemini, then saves
/// the result to Firestore via [WorkoutPlanRepository].
///
/// Flow:
///   1. Fetch user profile from Firestore (height, weight, gender, goal).
///   2. Build a prompt that lists only the exercises available in the app.
///   3. Send the prompt to Gemini and request a JSON response.
///   4. Parse the JSON into [WorkoutPlan] / [PlanDay] / [PlanExercise].
///   5. Persist via [WorkoutPlanRepository.savePlan].
///   6. Return the saved [WorkoutPlan] to the caller (UI).
/// Signature for the function that turns a prompt into the raw AI response.
///
/// Injecting a custom implementation (see [WorkoutPlanService.aiCaller]) lets
/// us exercise the whole generate → parse → save flow with a canned JSON
/// response, so the UI can be tested WITHOUT spending real Gemini quota.
typedef PlanAiCaller = Future<String> Function(String prompt);

class WorkoutPlanService {
  WorkoutPlanService({
    WorkoutPlanRepository? repository,
    FirebaseFirestore? firestore,
    this.aiCaller,
  })  : _repository = repository ?? WorkoutPlanRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final WorkoutPlanRepository _repository;
  final FirebaseFirestore _firestore;

  /// Optional override for the AI call. When null (the default, production
  /// behaviour) the real Gemini model is used. When provided, this function
  /// is called instead — used for free, offline testing with fake data.
  final PlanAiCaller? aiCaller;

  // Matches the model used by the chat coach. gemini-2.0-flash was retired by
  // Google ("no longer available"), so both features use gemini-2.5-flash.
  static const String _modelName = 'gemini-2.5-flash';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Generates and saves a weekly workout plan tailored to the current user.
  ///
  /// [userPrompt] allows the user to specify preferences like "3-day plan",
  /// "focus on legs", or "beginner level".
  ///
  /// Throws [WorkoutPlanServiceException] on any failure so the UI can show
  /// a meaningful error without catching generic exceptions.
  /// The most weeks a single generated plan may span (one month).
  static const int _kMaxWeeks = 4;

  Future<GeneratedPlan> generateAndSavePlan({String? userPrompt}) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw WorkoutPlanServiceException(
        'You must be signed in to generate a plan.',
      );
    }

    // Decide how many weeks to build from what the user asked for. Default is a
    // single week (unchanged, cheap path); multi-week only on explicit request.
    final (int weeks, bool exceededMonth) = _requestedWeeks(userPrompt);

    // 1. Fetch user profile.
    final Map<String, dynamic> profile = await _fetchProfile(uid);

    // ── Single-week (default) path — identical to the original behaviour. ──
    if (weeks <= 1) {
      final String prompt =
          _buildPrompt(profile: profile, userPrompt: userPrompt);
      final String rawJson = await _callGemini(prompt);
      final WorkoutPlan plan = _parsePlan(uid: uid, rawJson: rawJson);
      final String planId = await _repository.savePlan(plan);
      return GeneratedPlan(
        plan: plan.copyWith(id: planId, createdAt: DateTime.now()),
        totalWeeks: 1,
        exceededMonth: false,
      );
    }

    // ── Multi-week series path (progressive, up to 4 weeks). ──
    final String prompt = _buildSeriesPrompt(
      profile: profile,
      userPrompt: userPrompt,
      weeks: weeks,
    );
    // 4 weeks of content is ~4× the tokens, so raise the output budget to
    // avoid the JSON being truncated mid-plan.
    final String rawJson = await _callGemini(prompt, maxOutputTokens: 8192);
    final List<WorkoutPlan> weekPlans =
        _parseSeries(uid: uid, rawJson: rawJson, weeks: weeks);
    final WorkoutPlan firstWeek = await _repository.saveSeries(weekPlans);
    return GeneratedPlan(
      plan: firstWeek,
      totalWeeks: weekPlans.length,
      exceededMonth: exceededMonth,
    );
  }

  /// Works out how many weeks the user asked for.
  ///
  /// Returns the week count (1..4) and a flag that is true when the user asked
  /// for MORE than a month (e.g. a year) — the caller caps it at 4 weeks and
  /// tells the user longer plans aren't recommended.
  (int, bool) _requestedWeeks(String? prompt) {
    if (prompt == null) return (1, false);
    final String t = prompt.toLowerCase();

    // Clearly longer than a month → cap at 4 weeks, flag as not recommended.
    if (t.contains('year') || t.contains('quarter')) {
      return (_kMaxWeeks, true);
    }

    // "N month(s)"
    final RegExpMatch? mm = RegExp(r'(\d+)\s*months?').firstMatch(t);
    if (mm != null) {
      final int months = int.tryParse(mm.group(1) ?? '1') ?? 1;
      return (_kMaxWeeks, months >= 2);
    }
    // "a month" / "one month" / "monthly"
    if (t.contains('a month') ||
        t.contains('one month') ||
        t.contains('1 month') ||
        t.contains('this month') ||
        t.contains('monthly')) {
      return (_kMaxWeeks, false);
    }

    // "N week(s)"
    final RegExpMatch? wm = RegExp(r'(\d+)\s*weeks?').firstMatch(t);
    if (wm != null) {
      final int n = int.tryParse(wm.group(1) ?? '1') ?? 1;
      if (n > _kMaxWeeks) return (_kMaxWeeks, true);
      return (n < 1 ? 1 : n, false);
    }

    return (1, false);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Reads the user document from `users/{uid}` in Firestore.
  Future<Map<String, dynamic>> _fetchProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestore.collection('users').doc(uid).get();
    return doc.data() ?? <String, dynamic>{};
  }

  /// Builds the structured prompt sent to Gemini.
  ///
  /// The available exercise catalogue is embedded so Gemini can only pick
  /// exercises the app actually supports.
  String _buildPrompt({
    required Map<String, dynamic> profile,
    String? userPrompt,
  }) {
    // Extract profile fields with safe defaults.
    final String gender = (profile['gender'] as String?) ?? 'not specified';
    final dynamic age = profile['age'];
    final dynamic weight = profile['weight'];
    final dynamic height = profile['height'];
    final String activityLevel =
        (profile['activityLevel'] as String?) ?? 'moderate';
    final String goal = (profile['goal'] as String?) ?? 'general fitness';
    final String experience =
        (profile['experienceLevel'] as String?) ?? 'beginner';

    // Build the catalogue section of the prompt.
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

  /// Builds the prompt for a multi-week PROGRESSIVE plan.
  ///
  /// The response schema uses a `weeks` array (each week has its own `days`),
  /// so a single call returns the whole month. The word MULTIWEEK_TASK is a
  /// marker the fake AI caller keys off during free offline testing.
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

  /// Calls Gemini with the given prompt and returns the raw response text.
  ///
  /// If an [aiCaller] override was supplied, it is used instead of the real
  /// Gemini model (free offline testing path).
  Future<String> _callGemini(String prompt, {int maxOutputTokens = 2048}) async {
    final PlanAiCaller? override = aiCaller;
    if (override != null) {
      return override(prompt);
    }
    try {
      final GenerativeModel model = FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        generationConfig: GenerationConfig(
          // Encourage deterministic, valid JSON output.
          temperature: 0.3,
          maxOutputTokens: maxOutputTokens,
          // Return pure JSON (no ```json markdown fences) for robust parsing.
          responseMimeType: 'application/json',
          // Disable "thinking": gemini-2.5-flash spends output budget on hidden
          // reasoning by default, which truncated the JSON. Off = full budget
          // for the plan + lower token cost.
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
      // Log full detail for debugging; show the user a short message.
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

  /// Parses the raw JSON string from Gemini into a [WorkoutPlan].
  ///
  /// Strips markdown code fences if Gemini wraps the JSON despite the
  /// instruction not to.
  WorkoutPlan _parsePlan({
    required String uid,
    required String rawJson,
  }) {
    // Strip optional ```json ... ``` fences.
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
    final List<dynamic> rawDays =
        json['days'] as List<dynamic>? ?? <dynamic>[];

    final List<PlanDay> days = rawDays
        .whereType<Map<String, dynamic>>()
        .map(_parseDay)
        .toList();

    if (days.isEmpty) {
      debugPrint('PLAN_AI_EMPTY (all days/exercises filtered) cleaned=$cleaned');
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

  /// Parses a multi-week `weeks` JSON response into one [WorkoutPlan] per week.
  ///
  /// All weeks share a single [seriesId]. Week 1 is unlocked (draft, adoptable);
  /// weeks 2..N are locked until the user finishes the week before.
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

    // Build each week's day list, keeping at most [weeks] weeks.
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

  /// Converts a single day JSON map to a [PlanDay].
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

    return PlanDay(
      dayNumber: dayNumber,
      label: label,
      exercises: exercises,
    );
  }

  /// Converts a single exercise JSON map to a [PlanExercise].
  ///
  /// Validates the exerciseId against the local catalogue so we never save
  /// a plan referencing an exercise that doesn't exist in the app.
  PlanExercise _parseExercise(Map<String, dynamic> map) {
    final String exerciseId = map['exerciseId'] as String? ?? '';
    final String title = map['title'] as String? ?? 'Exercise';
    final String setsLabel = map['setsLabel'] as String? ?? '3 sets';

    // Verify the exercise exists in our catalogue.
    final bool valid = _availableExercises.any((e) => e.id == exerciseId);
    if (!valid) {
      // Return an empty-id exercise; the caller filters these out.
      return const PlanExercise(exerciseId: '', title: '', setsLabel: '');
    }

    return PlanExercise(
      exerciseId: exerciseId,
      title: title,
      setsLabel: setsLabel,
    );
  }
}

// ── Result type ────────────────────────────────────────────────────────────

/// The outcome of [WorkoutPlanService.generateAndSavePlan].
///
/// [plan] is the plan to show/adopt first — for a multi-week series this is
/// Week 1 (the only unlocked week). [totalWeeks] is 1 for a normal single-week
/// plan. [exceededMonth] is true when the user asked for longer than a month
/// and we capped it at 4 weeks.
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

// ── Exception type ─────────────────────────────────────────────────────────

/// Typed exception surfaced by [WorkoutPlanService] for clean error handling
/// in the UI layer.
class WorkoutPlanServiceException implements Exception {
  const WorkoutPlanServiceException(this.message);

  final String message;

  @override
  String toString() => 'WorkoutPlanServiceException: $message';
}