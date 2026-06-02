import 'package:flutter/material.dart';

import 'workout_plan_repository.dart';
import '../progress/progress_page.dart';

const Color _kPrimaryColor = Color(0xFF4CAF50);

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
  });

  final String text;
  final bool isUser;
  final bool isLoading;
}

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key, this.repository});

  final WorkoutPlanRepository? repository;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  late final WorkoutPlanRepository _repository;
  final TextEditingController _inputController = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          'Hi! Tell me your goal (e.g. "leg focus", "3-day plan", "beginner push"). '
          'I\'ll read your profile and build a workout plan.',
      isUser: false,
    ),
  ];
  bool _isGenerating = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WorkoutPlanRepository();
    _loadProfile();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final Map<String, dynamic>? profile =
          await _repository.fetchUserProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
      if (profile != null && profile.isNotEmpty) {
        final String name =
            '${profile['firstName'] ?? ''}'.trim();
        setState(() {
          _messages.add(
            _ChatMessage(
              text: name.isNotEmpty
                  ? 'Loaded profile for $name. Ready when you are.'
                  : 'Profile loaded. Ready when you are.',
              isUser: false,
            ),
          );
        });
      } else {
        setState(() {
          _messages.add(
            const _ChatMessage(
              text:
                  'No profile found yet — I\'ll use sensible defaults. '
                  'Update your profile for better recommendations.',
              isUser: false,
            ),
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'Could not load profile. I\'ll use default settings.',
            isUser: false,
          ),
        );
      });
    }
  }

  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messages.add(
        const _ChatMessage(
          text: 'Building your plan…',
          isUser: false,
          isLoading: true,
        ),
      );
      _isGenerating = true;
    });
    _inputController.clear();

    try {
      final Map<String, dynamic> profile =
          _profile ?? <String, dynamic>{'activityLevel': 'moderate'};
      final plan = await _repository.generateAndSavePlan(
        profile: profile,
        userPrompt: text,
      );
      await _repository.startPlan(plan.id);

      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(
          _ChatMessage(
            text:
                'Done! Created "${plan.title}" with ${plan.days.length} days '
                'and started it. Open Progress to see your checklist.',
            isUser: false,
          ),
        );
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isLoading) {
          _messages.removeLast();
        }
        _messages.add(
          _ChatMessage(
            text: 'Something went wrong: $e',
            isUser: false,
          ),
        );
        _isGenerating = false;
      });
    }
  }

  void _openProgress() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const ProgressPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('AI Chat'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _openProgress,
            child: const Text('Progress'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                final _ChatMessage message = _messages[index];
                return _ChatBubble(message: message);
              },
            ),
          ),
          Material(
            elevation: 8,
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !_isGenerating,
                        decoration: InputDecoration(
                          hintText: 'Describe your goal…',
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
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isGenerating ? null : _send,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: _kPrimaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final Alignment alignment =
        message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final Color bg =
        message.isUser ? _kPrimaryColor : Colors.grey.shade200;
    final Color fg = message.isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: message.isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(message.text, style: TextStyle(color: fg)),
                ],
              )
            : Text(message.text, style: TextStyle(color: fg)),
      ),
    );
  }
}
