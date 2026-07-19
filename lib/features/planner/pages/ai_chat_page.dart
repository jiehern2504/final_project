import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/workout_plan_models.dart';
import '../repositories/workout_plan_repository.dart';
import '../services/ai_chat_service.dart';
import '../services/workout_plan_service.dart';
import '../services/fake_plan_ai.dart';
import '../widgets/chat_bubble.dart';
import '../../progress/progress_page.dart';
import '../../../core/theme/app_colors.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final AiChatService _chatService = AiChatService();
  final WorkoutPlanRepository _planRepository = WorkoutPlanRepository();
  late final WorkoutPlanService _planService = WorkoutPlanService(
    repository: _planRepository,
    aiCaller: kUseFakeAiPlan ? fakePlanJson : null,
  );

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  final List<ChatMessage> _messages = <ChatMessage>[
    const ChatMessage(
      text:
          "Hi! I'm your personal fitness coach 💪\n\n"
          "Ask me anything about workouts, nutrition or healthy living — or "
          "say \"make me a workout plan\" and I'll build one you can track.",
      isUser: false,
    ),
  ];

  bool _isSending = false;

  int? _adoptingIndex;

  static const Color _kPrimary = AppColors.primary;
  static const Color _kBackground = AppColors.background;

  @override
  void initState() {
    super.initState();
    final String? initial = widget.initialMessage?.trim();
    if (initial != null && initial.isNotEmpty) {
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

  void _addMessage(ChatMessage message) {
    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  void _removeLastMessage() {
    if (_messages.isNotEmpty) {
      setState(() => _messages.removeLast());
    }
  }

  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();
    setState(() => _isSending = true);

    _addMessage(ChatMessage(text: text, isUser: true));

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

        _inputFocus.requestFocus();
      }
    }
  }

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
      _addMessage(ChatMessage.error('Something went wrong. Please try again.'));
    }
  }

  Future<void> _generatePlanReply(String userPrompt) async {
    try {
      final GeneratedPlan result = await _planService.generateAndSavePlan(
        userPrompt: userPrompt,
      );
      _removeLastMessage();

      if (result.exceededMonth) {
        _addMessage(
          const ChatMessage(
            text:
                "Plans longer than a month aren't recommended for "
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

  bool _isPlanRequest(String text) {
    final String t = text.toLowerCase();
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

  void _openProgress() {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const ProgressPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _MessageList(
              messages: _messages,
              scrollController: _scrollController,
              adoptingIndex: _adoptingIndex,
              onAdoptPlan: _adoptPlan,
            ),
          ),

          if (_messages.length == 1) _SuggestionChips(onTap: _sendSuggestion),

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
            decoration: BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
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
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Clear chat',
          onPressed: _isSending ? null : _clearChat,
        ),

        TextButton(onPressed: _openProgress, child: const Text('Progress')),
      ],
    );
  }

  void _sendSuggestion(String suggestion) {
    _inputController.text = suggestion;
    _send();
  }
}

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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String suggestion = _suggestions[index];
          return ActionChip(
            label: Text(suggestion, style: const TextStyle(fontSize: 12)),
            onPressed: () => onTap(suggestion),
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.primary),
            labelStyle: const TextStyle(color: AppColors.primary),
          );
        },
      ),
    );
  }
}

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

  static const Color _kPrimary = AppColors.primary;

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
                    hintText: 'Ask a fitness question… ',
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
