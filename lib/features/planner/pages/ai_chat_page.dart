import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';
import '../widgets/chat_bubble.dart';
import '../../progress/progress_page.dart';

/// AI Fitness Chat Page.
///
/// Provides a conversational Q&A experience powered by Gemini through
/// [AiChatService]. The assistant only answers questions about fitness,
/// workouts, nutrition and healthy lifestyle — off-topic questions are
/// politely declined by the model's system instruction.
///
/// This page does NOT generate workout plans.
/// For AI-generated plans see WorkoutPlanService / the Planner flow.
class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  // ── Services ───────────────────────────────────────────────────────────────
  final AiChatService _chatService = AiChatService();

  // ── UI controllers ─────────────────────────────────────────────────────────
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  // ── State ──────────────────────────────────────────────────────────────────
  final List<ChatMessage> _messages = <ChatMessage>[
    const ChatMessage(
      text: "Hi! I'm your personal fitness coach 💪\n\n"
          "Ask me anything about workouts, exercises, nutrition, "
          "or healthy lifestyle. How can I help you today?",
      isUser: false,
    ),
  ];

  bool _isSending = false;

  // ── Colour constants (aligned with AppColors) ──────────────────────────────
  static const Color _kPrimary = Color(0xFF4CAF50);
  static const Color _kBackground = Color(0xFFF9FBF9);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Scrolls the list to the very bottom after a frame has been rendered.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Appends [message] to the list and scrolls down.
  void _addMessage(ChatMessage message) {
    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  /// Removes the last message (used to replace the loading bubble).
  void _removeLastMessage() {
    if (_messages.isNotEmpty) {
      setState(() => _messages.removeLast());
    }
  }

  // ── Send logic ─────────────────────────────────────────────────────────────

  /// Sends the current input to Gemini and appends the response.
  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Clear input and lock UI immediately.
    _inputController.clear();
    setState(() => _isSending = true);

    // 1. Show user bubble.
    _addMessage(ChatMessage(text: text, isUser: true));

    // 2. Show loading / typing indicator.
    _addMessage(ChatMessage.loading());

    try {
      // 3. Call Gemini via AiChatService.
      final String reply = await _chatService.sendMessage(text);

      // 4. Replace loading bubble with the AI response.
      _removeLastMessage();
      _addMessage(ChatMessage(text: reply, isUser: false));
    } on AiChatException catch (e) {
      // Show the typed error message in an error bubble.
      _removeLastMessage();
      _addMessage(ChatMessage.error(e.message));
    } catch (_) {
      _removeLastMessage();
      _addMessage(
        ChatMessage.error('Something went wrong. Please try again.'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        // Re-focus the input for quick follow-up messages.
        _inputFocus.requestFocus();
      }
    }
  }

  /// Clears conversation history and resets the Gemini chat session.
  void _clearChat() {
    _chatService.reset();
    setState(() {
      _messages
        ..clear()
        ..add(
          const ChatMessage(
            text: "Chat cleared. What fitness question can I help you with?",
            isUser: false,
          ),
        );
    });
  }

  /// Navigates to [ProgressPage] (kept from original for navigation parity).
  void _openProgress() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ProgressPage(),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: <Widget>[
          // ── Message list ─────────────────────────────────────────────────
          Expanded(
            child: _MessageList(
              messages: _messages,
              scrollController: _scrollController,
            ),
          ),

          // ── Suggestion chips (shown only when no conversation yet) ───────
          if (_messages.length == 1) _SuggestionChips(onTap: _sendSuggestion),

          // ── Input bar ────────────────────────────────────────────────────
          _InputBar(
            controller: _inputController,
            focusNode: _inputFocus,
            isSending: _isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kPrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          const Text('Fitness Coach'),
        ],
      ),
      centerTitle: true,
      actions: <Widget>[
        // Clear conversation button.
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Clear chat',
          onPressed: _isSending ? null : _clearChat,
        ),
        // Keep the original Progress shortcut.
        TextButton(
          onPressed: _openProgress,
          child: const Text('Progress'),
        ),
      ],
    );
  }

  /// Sends a pre-written suggestion as if the user typed it.
  void _sendSuggestion(String suggestion) {
    _inputController.text = suggestion;
    _send();
  }
}

// ── Message list ────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.scrollController,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        return ChatBubble(message: messages[index]);
      },
    );
  }
}

// ── Suggestion chips ─────────────────────────────────────────────────────────

/// Quick-start prompts shown when the chat is empty.
class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.onTap});

  final ValueChanged<String> onTap;

  static const List<String> _suggestions = <String>[
    'How do I lose weight?',
    'Best beginner home workout?',
    'How many calories should I eat?',
    'How to build muscle at home?',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String suggestion = _suggestions[index];
          return ActionChip(
            label: Text(
              suggestion,
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => onTap(suggestion),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF4CAF50)),
            labelStyle: const TextStyle(color: Color(0xFF4CAF50)),
          );
        },
      ),
    );
  }
}

// ── Input bar ────────────────────────────────────────────────────────────────

/// The text field + send button anchored to the bottom of the screen.
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  static const Color _kPrimary = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: <Widget>[
              // ── Text field ───────────────────────────────────────────────
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !isSending,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Ask a fitness question…',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // ── Send button ──────────────────────────────────────────────
              IconButton.filled(
                onPressed: isSending ? null : onSend,
                style: IconButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                icon: isSending
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}