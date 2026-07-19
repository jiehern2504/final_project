import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/workout_plan_models.dart';
import 'typing_indicator.dart';
import '../../../core/theme/app_colors.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onAdoptPlan,
    this.adopting = false,
  });

  final ChatMessage message;

  final VoidCallback? onAdoptPlan;

  final bool adopting;

  static const Color _kPrimary = AppColors.primary;
  static const Color _kUserText = Colors.white;
  static const Color _kAiBubble = Color(0xFFEEEEEE);
  static const Color _kAiText = AppColors.text;
  static const Color _kErrorBubble = Color(0xFFFFEBEE);
  static const Color _kErrorText = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    if (message.isLoading) {
      return _BubbleShell(
        isUser: false,
        color: _kAiBubble,
        child: const TypingIndicator(),
      );
    }

    if (message.plan != null) {
      return _PlanMessage(
        plan: message.plan!,
        adopted: message.planAdopted,
        adopting: adopting,
        onAdopt: onAdoptPlan,
      );
    }

    final Color bubbleColor = message.isUser
        ? _kPrimary
        : message.isError
        ? _kErrorBubble
        : _kAiBubble;

    final Color textColor = message.isUser
        ? _kUserText
        : message.isError
        ? _kErrorText
        : _kAiText;

    return _BubbleShell(
      isUser: message.isUser,
      color: bubbleColor,
      child: Text(
        message.text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: textColor, height: 1.45),
      ),
    );
  }
}

class _BubbleShell extends StatelessWidget {
  const _BubbleShell({
    required this.isUser,
    required this.color,
    required this.child,
  });

  final bool isUser;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.80,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _PlanMessage extends StatelessWidget {
  const _PlanMessage({
    required this.plan,
    required this.adopted,
    required this.adopting,
    required this.onAdopt,
  });

  static const Color _kPrimary = AppColors.primary;
  static const Color _kText = AppColors.text;

  final WorkoutPlan plan;
  final bool adopted;
  final bool adopting;
  final VoidCallback? onAdopt;

  Color _withOpacity(Color color, double opacity) {
    final int a = (opacity * 255).round().clamp(0, 255);
    return color.withAlpha(a);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _withOpacity(_kPrimary, 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note, color: _kPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _kText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.days.length} days • only uses your tutorial exercises',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _withOpacity(_kText, 0.6)),
            ),
            const SizedBox(height: 10),
            ...plan.days.map((PlanDay day) => _DayBlock(day: day)),
            const SizedBox(height: 6),
            if (adopted)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: _kPrimary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Added to your progress',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _kPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: adopting ? null : onAdopt,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: adopting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(adopting ? 'Adding…' : 'Add to my progress'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.day});

  static const Color _kPrimary = AppColors.primary;
  static const Color _kText = AppColors.text;

  final PlanDay day;

  Color _withOpacity(Color color, double opacity) {
    final int a = (opacity * 255).round().clamp(0, 255);
    return color.withAlpha(a);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _kText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ...day.exercises.map(
            (PlanExercise e) => Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.circle,
                    size: 6,
                    color: _withOpacity(_kPrimary, 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _withOpacity(_kText, 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.setsLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _withOpacity(_kText, 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
