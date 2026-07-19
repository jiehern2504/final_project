import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class NumberWheel extends StatefulWidget {
  const NumberWheel({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final int min;
  final int max;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  State<NumberWheel> createState() => _NumberWheelState();
}

class _NumberWheelState extends State<NumberWheel> {
  late FixedExtentScrollController _controller;

  int get _count => widget.max - widget.min + 1;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: (widget.value - widget.min).clamp(0, _count - 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 70),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.primary, width: 2),
                bottom: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: 52,
            perspective: 0.002,
            diameterRatio: 1.6,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (int index) =>
                widget.onChanged(widget.min + index),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: _count,
              builder: (BuildContext context, int index) {
                final int number = widget.min + index;
                final bool selected = number == widget.value;
                return Center(
                  child: Text(
                    selected ? '$number ${widget.unit}' : '$number',
                    style: TextStyle(
                      fontSize: selected ? 30 : 20,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected
                          ? AppColors.text
                          : const Color(0xFFC4C9C4),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
