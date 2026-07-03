import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../health_calculator.dart';

/// The top-left "BMI | TDEE" segmented switch.
class CalcModeSwitch extends StatelessWidget {
  const CalcModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final CalcMode mode;
  final ValueChanged<CalcMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('BMI', CalcMode.bmi),
          _segment('TDEE', CalcMode.tdee),
        ],
      ),
    );
  }

  Widget _segment(String label, CalcMode value) {
    final bool selected = mode == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
