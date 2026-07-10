import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/workout_plan_models.dart';
import '../repositories/workout_plan_repository.dart';
import '../services/ai_chat_service.dart';
import '../services/workout_plan_service.dart';
import '../services/fake_plan_ai.dart';
import '../widgets/chat_bubble.dart';
import '../../progress/progress_page.dart';

/// AI Fitness Chat Page.
///
/// Provides a conversational Q&A experience powered by Gemini through
/// [AiChatService]. The assistant only answers questions about fitness,
/// workouts, nutrition and healthy lifestyle — off-topic questions are
/// politely declined by the model's system instruction.
///
/// When the user asks for a workout plan (e.g. "make me a workout plan"),
/// this page generates a trackable plan via [WorkoutPlanService] — built only
/// from the tutorial catalogue and matched to the user's profile — and lets
/// the user adopt it into progress tracking.
class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key, this.initialMessage});

  /// If provided, this text is sent automatically as the user's first message
  /// when the page opens (e.g. "help me to build workout plan").
  final String? initialMessage;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  // ── Services ───────────────────────────────────────────────────────────────
  final AiChatService _chatService = AiChatService();
  final WorkoutPlanRepository _planRepository = WorkoutPlanRepository();
  late final WorkoutPlanService _planService = WorkoutPlanService(
    repository: _planRepository,
    aiCaller: kUseFakeAiPlan ? fakePlanJson : null,
  );

  // ── UI controllers ─────────────────────────────────────────────────────────
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  // ── State ──────────────────────────────────────────────────────────────────
  final List<ChatMessage> _messages = <ChatMessage>[
    const ChatMessage(
      text: "Hi! I'm your personal fitness coach 💪\n\n"
          "Ask me anything about workouts, nutrition or healthy living — or "
          "say \"make me a workout plan\" and I'll build one you can track.",
      isUser: false,
    ),
  ];

  bool _isSending = false;

  /// Index of the plan message currently being adopted (shows a spinner on
  /// just that card); null when nothing is being adopted.
  int? _adoptingIndex;

  // ── Colour constants (aligned with AppColors) ──────────────────────────────
  static const Color _kPrimary = Color(0xFF4CAF50);
  static const Color _kBackground = Color(0xFFF9FBF9);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final String? initial = widget.initialMessage?.trim();
    if (initial != null && initial.isNotEmpty) {
      // Send after the first frame so the chat UI is built before we start.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _inputController.text = initial;
        _send();
      });
    }
  }

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

  /// Sends the current input. Plan requests generate a trackable plan;
  /// everything else is answered by the Q&A coach.
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
      if (_isPlanRequest(text)) {
        await _generatePlanReply(text);
      } else {
        await _sendQuestion(text);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        // Re-focus the input for quick follow-up messages.
        _inputFocus.requestFocus();
      }
    }
  }

  /// Normal fitness Q&A via Gemini.
  Future<void> _sendQuestion(String text) async {
    try {
      final String reply = await _chatService.sendMessage(text);
      _removeLastMessage();
      _addMessage(ChatMessage(text: reply, isUser: false));
    } on AiChatException catch (e) {
      _removeLastMessage();
      _addMessage(ChatMessage.error(e.message));
    } catch (_) {
      _removeLastMessage();
      _addMessage(
        ChatMessage.error('Something went wrong. Please try again.'),
      );
    }
  }

  /// Generates a trackable workout plan and shows it as a plan card.
  Future<void> _generatePlanReply(String userPrompt) async {
    try {
      final GeneratedPlan result = await _planService.generateAndSavePlan(
        userPrompt: userPrompt,
      );
      _removeLastMessage();

      // Longer-than-a-month requests are capped at 4 weeks.
      if (result.exceededMonth) {
        _addMessage(
          const ChatMessage(
            text: "Plans longer than a month aren't recommended for "
                "beginners, so I've kept it to 4 weeks.",
            isUser: false,
          ),
        );
      }

      final String intro = result.totalWeeks > 1
          ? "Here's a ${result.totalWeeks}-week progressive plan built from "
              "your tutorial exercises. Only Week 1 is unlocked — finish it to "
              "unlock Week 2, and so on. Add Week 1 to your progress to start."
          : "Here's a plan built only from your tutorial exercises and "
              "matched to your profile. Add it to your progress to start "
              "tracking each day.";
      _addMessage(ChatMessage(text: intro, isUser: false));
      _addMessage(ChatMessage.planResult(result.plan));
    } on WorkoutPlanServiceException catch (e) {
      _removeLastMessage();
      _addMessage(ChatMessage.error(e.message));
    } catch (_) {
      _removeLastMessage();
      _addMessage(
        ChatMessage.error('Could not build a plan. Please try again.'),
      );
    }
  }

  /// Heuristic: does [text] look like a request to build a workout plan?
  bool _isPlanRequest(String text) {
    final String t = text.toLowerCase();
    if (t.contains('计划') || t.contains('训练安排')) return true;
    const List<String> verbs = <String>[
      'make',
      'create',
      'generate',
      'build',
      'give me',
      'plan me',
      'design',
    ];
    final bool hasVerb = verbs.any(t.contains);
    if (t.contains('workout plan') ||
        t.contains('training plan') ||
        t.contains('weekly plan') ||
        t.contains('plan for me')) {
      return true;
    }
    if (hasVerb &&
        (t.contains('plan') ||
            t.contains('routine') ||
            t.contains('program'))) {
      return true;
    }
    return false;
  }

  /// Adopts the plan in message [index] into progress tracking.
  Future<void> _adoptPlan(int index) async {
    if (_adoptingIndex != null) return;
    final ChatMessage message = _messages[index];
    final WorkoutPlan? plan = message.plan;
    if (plan == null) return;

    setState(() => _adoptingIndex = index);
    try {
      await _planRepository.startPlan(plan.id);
      if (!mounted) return;
      setState(() {
        _messages[index] = message.copyWith(planAdopted: true);
        _adoptingIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan added to your progress. Good luck!'),
        ),
      );
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const ProgressPage(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _adoptingIndex = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add the plan. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
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
              adoptingIndex: _adoptingIndex,
              onAdoptPlan: _adoptPlan,
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
    required this.adoptingIndex,
    required this.onAdoptPlan,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final int? adoptingIndex;
  final ValueChanged<int> onAdoptPlan;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        return ChatBubble(
          message: messages[index],
          adopting: adoptingIndex == index,
          onAdoptPlan: messages[index].plan != null
              ? () => onAdoptPlan(index)
              : null,
        );
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
    'Make me a workout plan',
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