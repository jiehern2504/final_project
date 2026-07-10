import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';

/// Wraps Firebase AI Logic (Gemini) for fitness-only conversational Q&A.
class AiChatService {
  AiChatService() {
    _initSession();
  }

  late ChatSession _chat;

  static const String _modelName = 'gemini-2.5-flash';

  static const String _systemInstruction = '''
You are a certified personal fitness coach and nutrition expert. 
Your role is to help users with:
- Exercise techniques and workout routines
- Fitness goals (weight loss, muscle building, endurance, flexibility)
- Nutrition advice and healthy eating habits
- Recovery, rest, and injury prevention
- Home workouts and bodyweight exercises
- Beginner fitness guidance and motivation

Important rules:
1. ONLY answer questions related to fitness, workouts, exercise, nutrition, and healthy lifestyle.
2. If a user asks about anything unrelated (politics, coding, entertainment, relationships, etc.), politely decline and explain that you only provide fitness and wellness assistance.
3. Keep answers practical, encouraging, and beginner-friendly.
4. Never provide medical diagnoses or replace professional medical advice.
5. Always recommend consulting a doctor before starting a new fitness program if the user mentions health conditions.
6. ALWAYS reply in English only, even if the user writes in another language. If the user writes in another language, answer their question in English and gently ask them to use English.
''';

  void _initSession() {
    final GenerativeModel model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      systemInstruction: Content.system(_systemInstruction),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );
    _chat = model.startChat();
  }

  /// Sends [userMessage] to Gemini and returns the AI's text response.
  ///
  /// Throws [AiChatException] with the REAL error message so the UI bubble
  /// always shows exactly what went wrong (helpful for debugging).
  Future<String> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) {
      throw const AiChatException('Message cannot be empty.');
    }

    try {
      final GenerateContentResponse response = await _chat.sendMessage(
        Content.text(userMessage.trim()),
      );

      final String? text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw const AiChatException(
          'The AI returned an empty response. Please try again.',
        );
      }

      return text.trim();

    } on AiChatException {
      rethrow;

    } on FirebaseException catch (e) {
      // Surface the Firebase error code + message for easy diagnosis.
      throw AiChatException(
        '[Firebase ${e.code}] ${e.message ?? 'Unknown Firebase error'}',
      );

    } catch (e) {
      // Surface the raw error — this is the key change that shows the real problem.
      throw AiChatException('${e.runtimeType}: ${e.toString()}');
    }
  }

  /// Resets the chat session (clears conversation history).
  void reset() => _initSession();
}

/// Typed exception from [AiChatService].
class AiChatException implements Exception {
  const AiChatException(this.message);
  final String message;

  @override
  String toString() => 'AiChatException: $message';
}