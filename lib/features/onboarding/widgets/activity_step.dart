import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A single selectable activity level. [id] matches the Firestore
/// `activityLevel` value; [factor] is only shown for context.
class ActivityOption {
  const ActivityOption(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;
}

/// The activity levels offered during onboarding. Ids match the values the
/// rest of the app stores in `activityLevel`.
const List<ActivityOption> kOnboardingActivities = <ActivityOption>[
  ActivityOption('sedentary', 'Sedentary', 'Rarely exercise'),
  ActivityOption('light', 'Light', '1-2 days / week'),
  ActivityOption('moderate', 'Moderate', '3-4 days / week'),
  ActivityOption('active', 'Active', '5+ days / week'),
];

/// A vertical list of activity levels; the selected one is highlighted.
class ActivityStep extends StatelessWidget {
  const ActivityStep({
    super.key,
    required this.activity,
    required this.onChanged,
  });

  final String activity;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: kOnboardingActivities.map((ActivityOption option) {
          final bool selected = option.id == activity;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => onChanged(option.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
