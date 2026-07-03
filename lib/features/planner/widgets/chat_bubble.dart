import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/workout_plan_models.dart';
import 'typing_indicator.dart';

/// A single chat bubble that renders one [ChatMessage].
///
/// • User messages  → right-aligned, primary green background.
/// • AI messages    → left-aligned, light grey background.
/// • Loading state  → left-aligned grey bubble with [TypingIndicator].
/// • Error state    → left-aligned with a subtle red tint.
/// • Plan message   → left-aligned wide card with an "Add to my progress"
///   action (see [message.plan]).
///
/// Reuses the app-wide colour constants so the bubble style always matches
/// the rest of the UI without importing [AppColors] (avoiding circular deps).
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onAdoptPlan,
    this.adopting = false,
  });

  final ChatMessage message;

  /// Called when the user taps "Add to my progress" on a plan message.
  final VoidCallback? onAdoptPlan;

  /// True while the adopt action is in flight (disables the button).
  final bool adopting;

  // ── Colour constants (aligned with AppColors / home_page palette) ─────────
  static const Color _kPrimary = Color(0xFF4CAF50);
  static const Color _kUserText = Colors.white;
  static const Color _kAiBubble = Color(0xFFEEEEEE);
  static const Color _kAiText = Color(0xFF333333);
  static const Color _kErrorBubble = Color(0xFFFFEBEE);
  static const Color _kErrorText = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    // Loading placeholder — show typing indicator instead of text.
    if (message.isLoading) {
      return _BubbleShell(
        isUser: false,
        color: _kAiBubble,
        child: const TypingIndicator(),
      );
    }

    // Plan card — a wider, interactive message.
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: textColor,
          height: 1.45,
        ),
      ),
    );
  }
}

// ── Private shell ──────────────────────────────────────────────────────────

/// Handles alignment, margin, max-width constraint and the rounded shape.
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
          // Bubbles never exceed 80 % of the screen width.
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

// ── Plan message ─────────────────────────────────────────────────────────────

/// A left-aligned wide card that shows a generated [WorkoutPlan] with an
/// "Add to my progress" button.
class _PlanMessage extends StatelessWidget {
  const _PlanMessage({
    required this.plan,
    required this.adopted,
    required this.adopting,
    required this.onAdopt,
  });

  static const Color _kPrimary = Color(0xFF4CAF50);
  static const Color _kText = Color(0xFF333333);

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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _withOpacity(_kText, 0.6),
                  ),
            ),
            const SizedBox(height: 10),
            ...plan.days.map((PlanDay day) => _DayBlock(day: day)),
            const SizedBox(height: 6),
            if (adopted)
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: _kPrimary, size: 20),
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

  static const Color _kPrimary = Color(0xFF4CAF50);
  static const Color _kText = Color(0xFF333333);

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
                  Icon(Icons.circle,
                      size: 6, color: _withOpacity(_kPrimary, 0.6)),
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
