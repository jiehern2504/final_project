import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../health_calculator.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.mode,
    required this.bmi,
    required this.bmr,
    required this.tdee,
  });

  final CalcMode mode;
  final double? bmi;
  final double? bmr;
  final double? tdee;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: mode == CalcMode.bmi ? _buildBmi() : _buildTdee(),
    );
  }

  Widget _buildBmi() {
    final BmiLevel? level = HealthCalculator.categorize(bmi);
    return Column(
      children: [
        Text(
          'Your BMI',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          bmi == null ? '--' : bmi!.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            height: 1.05,
          ),
        ),
        Text(
          'kg/m²',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (level != null) ...[
          const SizedBox(height: 12),
          _CategoryChip(level: level),
        ],
        const SizedBox(height: 16),
        _BmiBand(bmi: bmi),
      ],
    );
  }

  Widget _buildTdee() {
    return Column(
      children: [
        Text(
          'Daily energy (TDEE)',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          tdee == null ? '--' : formatCalories(tdee!),
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            height: 1.05,
          ),
        ),
        Text(
          'kcal / day · maintain weight',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _TdeeBreakdown(bmr: bmr, tdee: tdee),
      ],
    );
  }
}

class _BmiLevelStyle {
  const _BmiLevelStyle(this.fill, this.text);
  final Color fill;
  final Color text;

  static _BmiLevelStyle of(BmiLevel level) {
    switch (level) {
      case BmiLevel.underweight:
        return const _BmiLevelStyle(Color(0xFF85B7EB), Color(0xFF185FA5));
      case BmiLevel.normal:
        return const _BmiLevelStyle(Color(0xFF97C459), Color(0xFF3B6D11));
      case BmiLevel.overweight:
        return const _BmiLevelStyle(Color(0xFFFAC775), Color(0xFF854F0B));
      case BmiLevel.obese:
        return const _BmiLevelStyle(Color(0xFFF09595), Color(0xFFA32D2D));
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.level});

  final BmiLevel level;

  @override
  Widget build(BuildContext context) {
    final _BmiLevelStyle style = _BmiLevelStyle.of(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: style.fill.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: style.text,
        ),
      ),
    );
  }
}

class _BmiBand extends StatelessWidget {
  const _BmiBand({required this.bmi});

  final double? bmi;

  @override
  Widget build(BuildContext context) {
    final double? value = bmi;

    final double fraction = value == null
        ? 0
        : (value / 40).clamp(0.0, 1.0).toDouble();

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 185,
                        child: ColoredBox(
                          color: Color(0xFF85B7EB),
                          child: SizedBox(height: 8),
                        ),
                      ),
                      Expanded(
                        flex: 65,
                        child: ColoredBox(
                          color: Color(0xFF97C459),
                          child: SizedBox(height: 8),
                        ),
                      ),
                      Expanded(
                        flex: 50,
                        child: ColoredBox(
                          color: Color(0xFFFAC775),
                          child: SizedBox(height: 8),
                        ),
                      ),
                      Expanded(
                        flex: 100,
                        child: ColoredBox(
                          color: Color(0xFFF09595),
                          child: SizedBox(height: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (value != null)
                  Positioned(
                    left: (fraction * width - 6).clamp(0.0, width - 12),
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.text,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final BmiLevel level in BmiLevel.values)
              Text(
                level.label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9A9A9A)),
              ),
          ],
        ),
      ],
    );
  }
}

class _TdeeBreakdown extends StatelessWidget {
  const _TdeeBreakdown({required this.bmr, required this.tdee});

  final double? bmr;
  final double? tdee;

  @override
  Widget build(BuildContext context) {
    final List<_BreakdownItem> items = <_BreakdownItem>[
      _BreakdownItem('BMR (base)', bmr, AppColors.textSecondary),
      _BreakdownItem(
        'Lose fat',
        tdee == null ? null : tdee! - 500,
        AppColors.primary,
      ),
      _BreakdownItem('Maintain', tdee, AppColors.text),
      _BreakdownItem(
        'Build muscle',
        tdee == null ? null : tdee! + 300,
        AppColors.secondary,
      ),
    ];

    return Column(
      children: [
        _row(items[0], items[1]),
        const SizedBox(height: 10),
        _row(items[2], items[3]),
      ],
    );
  }

  Widget _row(_BreakdownItem left, _BreakdownItem right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _BreakdownCell(item: left)),
          const SizedBox(width: 10),
          Expanded(child: _BreakdownCell(item: right)),
        ],
      ),
    );
  }
}

class _BreakdownItem {
  const _BreakdownItem(this.label, this.value, this.color);
  final String label;
  final double? value;
  final Color color;
}

class _BreakdownCell extends StatelessWidget {
  const _BreakdownCell({required this.item});

  final _BreakdownItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              text: item.value == null ? '--' : formatCalories(item.value!),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: item.color,
              ),
              children: const [
                TextSpan(
                  text: ' kcal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF9A9A9A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
