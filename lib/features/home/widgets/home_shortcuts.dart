part of '../home_page.dart';

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.primaryColor,
    required this.secondaryColor,
    required this.cardColor,
    required this.textColor,
    required this.onWorkoutTap,
    required this.onProgressTap,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onWorkoutTap;
  final VoidCallback onProgressTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutCard(
            icon: Icons.fitness_center_rounded,
            label: 'Workout',
            color: secondaryColor,
            cardColor: cardColor,
            textColor: textColor,
            onTap: onWorkoutTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ShortcutCard(
            icon: Icons.insights_outlined,
            label: 'Progress Tracking',
            color: primaryColor,
            cardColor: cardColor,
            textColor: textColor,
            onTap: onProgressTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ShortcutCard(
            icon: Icons.local_fire_department_outlined,
            label: 'TDEE Calculator',
            color: secondaryColor,
            cardColor: cardColor,
            textColor: textColor,
            onTap: () => _openTdee(context),
          ),
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.cardColor,
    required this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _withOpacity(Colors.black, 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _withOpacity(color, 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
