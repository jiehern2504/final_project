import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class WeightRuler extends StatefulWidget {
  const WeightRuler({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final int min;
  final int max;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<WeightRuler> createState() => _WeightRulerState();
}

class _WeightRulerState extends State<WeightRuler> {
  static const double _tickSpacing = 9;
  final ScrollController _controller = ScrollController();
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final int index = (_controller.offset / _tickSpacing).round();
    final int value = (widget.min + index).clamp(widget.min, widget.max);
    if (value != widget.value) widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final int count = widget.max - widget.min + 1;

    return Column(
      children: [
        RichText(
          text: TextSpan(
            text: '${widget.value}',
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
            children: const [
              TextSpan(
                text: ' kg',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 60,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double sidePad = constraints.maxWidth / 2;
              if (!_initialised) {
                _initialised = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_controller.hasClients) {
                    _controller.jumpTo(
                      (widget.value - widget.min) * _tickSpacing,
                    );
                  }
                });
              }
              return Stack(
                alignment: Alignment.center,
                children: [
                  ListView.builder(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    itemCount: count,
                    padding: EdgeInsets.symmetric(horizontal: sidePad),
                    itemBuilder: (BuildContext context, int index) {
                      final bool major = (widget.min + index) % 5 == 0;
                      return SizedBox(
                        width: _tickSpacing,
                        child: Center(
                          child: Container(
                            width: 2,
                            height: major ? 26 : 14,
                            color: major
                                ? AppColors.secondary
                                : const Color(0xFFE0C9A0),
                          ),
                        ),
                      );
                    },
                  ),
                  IgnorePointer(
                    child: Container(
                      width: 3,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
