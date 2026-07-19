import 'workout_plan_models.dart';

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.isError = false,
    this.plan,
    this.planAdopted = false,
  });

  final String text;

  final bool isUser;

  final bool isLoading;

  final bool isError;

  final WorkoutPlan? plan;

  final bool planAdopted;

  factory ChatMessage.loading() =>
      const ChatMessage(text: '', isUser: false, isLoading: true);

  factory ChatMessage.error(String message) =>
      ChatMessage(text: message, isUser: false, isError: true);

  factory ChatMessage.planResult(WorkoutPlan plan) =>
      ChatMessage(text: '', isUser: false, plan: plan);

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
