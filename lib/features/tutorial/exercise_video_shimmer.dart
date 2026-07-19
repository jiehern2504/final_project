import 'package:flutter/material.dart';

class ExerciseVideoShimmer extends StatefulWidget {
  const ExerciseVideoShimmer({
    super.key,
    required this.height,
    this.clipTopRadius = false,
  });

  final double height;
  final bool clipTopRadius;

  @override
  State<ExerciseVideoShimmer> createState() => _ExerciseVideoShimmerState();
}

class _ExerciseVideoShimmerState extends State<ExerciseVideoShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.35,
      end: 0.55,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.clipTopRadius
        ? const BorderRadius.vertical(top: Radius.circular(16))
        : BorderRadius.zero;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            height: widget.height,
            width: double.infinity,
            color: Color.lerp(
              const Color(0xFFE8E8E8),
              const Color(0xFFD0D0D0),
              _opacity.value,
            ),
          ),
        );
      },
    );
  }
}
