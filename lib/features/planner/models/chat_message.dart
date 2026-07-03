import 'workout_plan_models.dart';

/// Represents a single message in the AI fitness chat conversation.
///
/// Used by both [AiChatPage] and [AiChatService] so all state lives
/// in one place rather than as private inner classes.
class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.isError = false,
    this.plan,
    this.planAdopted = false,
  });

  /// The text content to display in the chat bubble.
  final String text;

  /// True when the message was sent by the user; false for AI responses.
  final bool isUser;

  /// True while waiting for the AI to respond (shows typing indicator).
  final bool isLoading;

  /// True when the AI returned an error; displayed with a distinct style.
  final bool isError;

  /// When non-null, this message shows a generated workout plan card with an
  /// "Add to my progress" action instead of plain text.
  final WorkoutPlan? plan;

  /// True once the user has adopted [plan] into progress tracking.
  final bool planAdopted;

  /// Convenience factory for a loading placeholder shown while Gemini thinks.
  factory ChatMessage.loading() => const ChatMessage(
    text: '',
    isUser: false,
    isLoading: true,
  );

  /// Convenience factory for an error reply from the AI layer.
  factory ChatMessage.error(String message) => ChatMessage(
    text: message,
    isUser: false,
    isError: true,
  );

  /// Convenience factory for a generated-plan message.
  factory ChatMessage.planResult(WorkoutPlan plan) => ChatMessage(
    text: '',
    isUser: false,
    plan: plan,
  );

  /// Creates a copy with only the specified fields replaced.
  ChatMessage copyWith({
    String? text,
    bool? isUser,
    bool? isLoading,
    bool? isError,
    WorkoutPlan? plan,
    bool? planAdopted,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
      plan: plan ?? this.plan,
      planAdopted: planAdopted ?? this.planAdopted,
    );
  }
}
