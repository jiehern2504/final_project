import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'bear_mascot.dart';
import 'onboarding_scaffold.dart';

/// One slide of the intro carousel: a mascot panel, headline, subtitle, page
/// dots and a primary button.
class IntroSlide extends StatelessWidget {
  const IntroSlide({
    super.key,
    required this.index,
    required this.total,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onNext,
  });

  final int index;
  final int total;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final Color panelColor = index.isOdd
        ? AppColors.secondary.withValues(alpha: 0.14)
        : AppColors.primary.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Center(child: BearMascot(size: 140)),
              ),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _Dots(active: index, total: total),
          const SizedBox(height: 18),
          PrimaryButton(label: buttonLabel, onPressed: onNext),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.active, required this.total});

  final int active;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(total, (int i) {
        final bool on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: on ? AppColors.primary : const Color(0xFFD5DED5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
