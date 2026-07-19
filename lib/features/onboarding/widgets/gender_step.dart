import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class GenderStep extends StatelessWidget {
  const GenderStep({super.key, required this.gender, required this.onChanged});

  final String gender;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _GenderCard(
          value: 'male',
          label: 'Male',
          icon: Icons.male,
          selected: gender == 'male',
          onTap: () => onChanged('male'),
        ),
        const SizedBox(width: 16),
        _GenderCard(
          value: 'female',
          label: 'Female',
          icon: Icons.female,
          selected: gender == 'female',
          onTap: () => onChanged('female'),
        ),
      ],
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 124,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : const Color(0xFFF0F2F0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
