import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import 'typing_indicator.dart';

/// A single chat bubble that renders one [ChatMessage].
///
/// • User messages  → right-aligned, primary green background.
/// • AI messages    → left-aligned, light grey background.
/// • Loading state  → left-aligned grey bubble with [TypingIndicator].
/// • Error state    → left-aligned with a subtle red tint.
///
/// Reuses the app-wide colour constants so the bubble style always matches
/// the rest of the UI without importing [AppColors] (avoiding circular deps).
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

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