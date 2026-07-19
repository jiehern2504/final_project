import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class GenderToggle extends StatelessWidget {
  const GenderToggle({
    super.key,
    required this.gender,
    required this.onChanged,
  });

  final String gender;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(Icons.male, 'male'),
        const SizedBox(width: 8),
        _button(Icons.female, 'female'),
      ],
    );
  }

  Widget _button(IconData icon, String value) {
    final bool selected = gender == value;
    return Material(
      color: selected
          ? AppColors.secondary.withValues(alpha: 0.18)
          : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: selected ? AppColors.secondary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
