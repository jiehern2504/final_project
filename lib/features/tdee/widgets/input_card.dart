import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../health_calculator.dart';

/// The white card holding the editable inputs. The "Activity" row only appears
/// in TDEE mode (BMI doesn't need it).
class InputCard extends StatelessWidget {
  const InputCard({
    super.key,
    required this.mode,
    required this.ageController,
    required this.heightController,
    required this.weightController,
    required this.activity,
    required this.onActivityChanged,
  });

  final CalcMode mode;
  final TextEditingController ageController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final String activity;
  final ValueChanged<String> onActivityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
      child: Column(
        children: [
          _InputRow(
            icon: Icons.cake_outlined,
            label: 'Age',
            controller: ageController,
            unit: 'yrs',
          ),
          const Divider(height: 1),
          _InputRow(
            icon: Icons.height,
            label: 'Height',
            controller: heightController,
            unit: 'cm',
          ),
          const Divider(height: 1),
          _InputRow(
            icon: Icons.monitor_weight_outlined,
            label: 'Weight',
            controller: weightController,
            unit: 'kg',
          ),
          if (mode == CalcMode.tdee) ...[
            const Divider(height: 1),
            _ActivityRow(activity: activity, onChanged: onActivityChanged),
          ],
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.icon,
    required this.label,
    required this.controller,
    required this.unit,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const Spacer(),
          SizedBox(
            width: 72,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                hintText: '--',
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 26,
            child: Text(
              unit,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.onChanged});

  final String activity;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.directions_run, size: 20, color: AppColors.secondary),
          const SizedBox(width: 8),
          Text(
            'Activity',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const Spacer(),
          DropdownButton<String>(
            value: activity,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            items: kActivityLabels.entries
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
