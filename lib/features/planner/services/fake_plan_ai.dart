/// Dev/testing helpers for AI plan generation.
///
/// When the app is launched with `--dart-define=FAKE_AI_PLAN=true`, plan
/// generation uses [fakePlanJson] instead of calling Gemini — so the full
/// flow (generate → show → adopt) can be verified for free. In normal /
/// production builds [kUseFakeAiPlan] is `false`, so this has no effect.
library;

const bool kUseFakeAiPlan = bool.fromEnvironment('FAKE_AI_PLAN');

/// A canned, catalogue-valid plan JSON returned by the fake AI caller.
/// Every `exerciseId` here exists in the tutorial catalogue, so nothing gets
/// filtered out during parsing.
Future<String> fakePlanJson(String prompt) async {
  await Future<void>.delayed(const Duration(milliseconds: 600));
  // The multi-week prompt carries a MULTIWEEK_TASK marker — return a small
  // 3-week series (2 days each) so the whole unlock flow can be tested fast.
  if (prompt.contains('MULTIWEEK_TASK')) {
    return _fakeSeriesJson;
  }
  return '''
{
  "title": "Full Body Beginner · 3-Day Plan (Demo)",
  "days": [
    {
      "dayNumber": 1,
      "label": "Day 1 – Full Body",
      "exercises": [
        {"exerciseId": "bodyweight_squats", "title": "Bodyweight Squats", "setsLabel": "3 × 10–15 reps"},
        {"exerciseId": "push_ups", "title": "Push-ups", "setsLabel": "3 × 8–12 reps"},
        {"exerciseId": "hand_plank", "title": "Hand Plank", "setsLabel": "3 × 30–45 sec"}
      ]
    },
    {
      "dayNumber": 2,
      "label": "Day 2 – Lower Body",
      "exercises": [
        {"exerciseId": "forward_lunges", "title": "Forward Lunges", "setsLabel": "3 × 8–12 reps/side"},
        {"exerciseId": "glute_bridges", "title": "Glute Bridges", "setsLabel": "3 × 10–15 reps"},
        {"exerciseId": "crunches", "title": "Crunches", "setsLabel": "3 × 12–20 reps"}
      ]
    },
    {
      "dayNumber": 3,
      "label": "Day 3 – Upper Body",
      "exercises": [
        {"exerciseId": "incline_push_ups", "title": "Incline Push-ups", "setsLabel": "3 × 8–15 reps"},
        {"exerciseId": "pike_push_ups", "title": "Pike Push-ups", "setsLabel": "3 × 6–10 reps"},
        {"exerciseId": "superman", "title": "Superman", "setsLabel": "3 × 10–15 reps"}
      ]
    }
  ]
}
''';
}

/// A canned 3-week progressive series JSON for offline testing of the
/// multi-week unlock flow. 2 days per week keeps completion fast during tests.
const String _fakeSeriesJson = '''
{
  "title": "Progressive Home Plan (Demo)",
  "weeks": [
    {
      "weekNumber": 1,
      "label": "Week 1 – Foundation",
      "days": [
        {
          "dayNumber": 1,
          "label": "Day 1 – Full Body",
          "exercises": [
            {"exerciseId": "bodyweight_squats", "title": "Bodyweight Squats", "setsLabel": "3 × 10 reps"},
            {"exerciseId": "incline_push_ups", "title": "Incline Push-ups", "setsLabel": "3 × 8 reps"}
          ]
        },
        {
          "dayNumber": 2,
          "label": "Day 2 – Core",
          "exercises": [
            {"exerciseId": "crunches", "title": "Crunches", "setsLabel": "3 × 12 reps"},
            {"exerciseId": "hand_plank", "title": "Hand Plank", "setsLabel": "3 × 30 sec"}
          ]
        }
      ]
    },
    {
      "weekNumber": 2,
      "label": "Week 2 – Build",
      "days": [
        {
          "dayNumber": 1,
          "label": "Day 1 – Full Body",
          "exercises": [
            {"exerciseId": "bodyweight_squats", "title": "Bodyweight Squats", "setsLabel": "3 × 15 reps"},
            {"exerciseId": "push_ups", "title": "Push-ups", "setsLabel": "3 × 10 reps"}
          ]
        },
        {
          "dayNumber": 2,
          "label": "Day 2 – Lower Body",
          "exercises": [
            {"exerciseId": "forward_lunges", "title": "Forward Lunges", "setsLabel": "3 × 10 reps/side"},
            {"exerciseId": "glute_bridges", "title": "Glute Bridges", "setsLabel": "3 × 15 reps"}
          ]
        }
      ]
    },
    {
      "weekNumber": 3,
      "label": "Week 3 – Push",
      "days": [
        {
          "dayNumber": 1,
          "label": "Day 1 – Upper Body",
          "exercises": [
            {"exerciseId": "decline_push_ups", "title": "Decline Push-ups", "setsLabel": "3 × 10 reps"},
            {"exerciseId": "pike_push_ups", "title": "Pike Push-ups", "setsLabel": "3 × 8 reps"}
          ]
        },
        {
          "dayNumber": 2,
          "label": "Day 2 – Core & Legs",
          "exercises": [
            {"exerciseId": "bulgarian_split_squats", "title": "Bulgarian Split Squats", "setsLabel": "3 × 12 reps"},
            {"exerciseId": "laying_leg_raises", "title": "Laying Leg Raises", "setsLabel": "3 × 12 reps"}
          ]
        }
      ]
    }
  ]
}
''';
