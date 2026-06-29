import 'package:flutter/material.dart';

/// Three bouncing dots that indicate the AI is composing a response.
///
/// Each dot animates with a staggered delay so they appear to "wave"
/// rather than all bouncing in sync.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  static const int _dotCount = 3;
  static const Duration _period = Duration(milliseconds: 600);
  static const Duration _stagger = Duration(milliseconds: 160);
  static const double _dotSize = 8;
  static const double _bounceHeight = 5;
  static const Color _dotColor = Color(0xFF9E9E9E);

  final List<AnimationController> _controllers = <AnimationController>[];
  final List<Animation<double>> _animations = <Animation<double>>[];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < _dotCount; i++) {
      final AnimationController controller = AnimationController(
        vsync: this,
        duration: _period,
      );

      final Animation<double> animation = Tween<double>(
        begin: 0,
        end: -_bounceHeight,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );

      _controllers.add(controller);
      _animations.add(animation);

      // Stagger each dot's loop start.
      Future<void>.delayed(_stagger * i, () {
        if (mounted) {
          controller.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final AnimationController c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _dotSize + _bounceHeight + 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List<Widget>.generate(_dotCount, (int i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (BuildContext context, Widget? child) {
              return Transform.translate(
                offset: Offset(0, _animations[i].value),
                child: child,
              );
            },
            child: Container(
              width: _dotSize,
              height: _dotSize,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(
                color: _dotColor,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}