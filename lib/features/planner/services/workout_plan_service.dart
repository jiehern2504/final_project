import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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
class WorkoutPlanService {
  WorkoutPlanService({
    WorkoutPlanRepository? repository,
    FirebaseFirestore? firestore,
  })  : _repository = repository ?? WorkoutPlanRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final WorkoutPlanRepository _repository;
  final FirebaseFirestore _firestore;

  static const String _modelName = 'gemini-2.0-flash';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Generates and saves a weekly workout plan tailored to the current user.
  ///
  /// [userPrompt] allows the user to specify preferences like "3-day plan",
  /// "focus on legs", or "beginner level".
  ///
  /// Throws [WorkoutPlanServiceException] on any failure so the UI can show
  /// a meaningful error without catching generic exceptions.
  Future<WorkoutPlan> generateAndSavePlan({String? userPrompt}) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw WorkoutPlanServiceException(
        'You must be signed in to generate a plan.',
      );
    }

    // 1. Fetch user profile.
    final Map<String, dynamic> profile = await _fetchProfile(uid);

    // 2. Build the prompt.
    final String prompt = _buildPrompt(profile: profile, userPrompt: userPrompt);

    // 3. Call Gemini.
    final String rawJson = await _callGemini(prompt);

    // 4. Parse into domain models.
    final WorkoutPlan plan = _parsePlan(uid: uid, rawJson: rawJson);

    // 5. Persist.
    final String planId = await _repository.savePlan(plan);

    // 6. Return hydrated plan with the Firestore-assigned ID.
    return WorkoutPlan(
      id: planId,
      userId: plan.userId,
      title: plan.title,
      status: plan.status,
      days: plan.days,
      progress: plan.progress,
      createdAt: DateTime.now(),
    );
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

  /// Calls Gemini with the given prompt and returns the raw response text.
  Future<String> _callGemini(String prompt) async {
    try {
      final GenerativeModel model = FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        generationConfig: GenerationConfig(
          // Encourage deterministic, valid JSON output.
          temperature: 0.3,
          maxOutputTokens: 2048,
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
      return text.trim();
    } on FirebaseException catch (e) {
      throw WorkoutPlanServiceException(
        'Firebase AI error: ${e.message ?? 'Unknown error'}.',
      );
    } catch (e) {
      if (e is WorkoutPlanServiceException) rethrow;
      throw WorkoutPlanServiceException(
        'Failed to contact the AI. Please check your connection.',
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

// ── Exception type ─────────────────────────────────────────────────────────

/// Typed exception surfaced by [WorkoutPlanService] for clean error handling
/// in the UI layer.
class WorkoutPlanServiceException implements Exception {
  const WorkoutPlanServiceException(this.message);

  final String message;

  @override
  String toString() => 'WorkoutPlanServiceException: $message';
}