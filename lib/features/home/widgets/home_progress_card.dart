part of '../home_page.dart';

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.primaryColor,
    required this.cardColor,
    required this.textColor,
    required this.onTapWithPlan,
    required this.onTapNoPlan,
    required this.repository,
  });

  final Color primaryColor;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onTapWithPlan;
  final VoidCallback onTapNoPlan;
  final WorkoutPlanRepository repository;

  @override
  Widget build(BuildContext context) {
    final WorkoutPlanRepository repo = repository;

    return StreamBuilder<WorkoutPlan?>(
      stream: repo.watchActivePlan(),
      builder: (BuildContext context, AsyncSnapshot<WorkoutPlan?> snapshot) {
        final PlanProgress progress =
            snapshot.data?.progress ??
            const PlanProgress(completedDays: 0, totalDays: 0);
        final double fraction = progress.fraction;
        final int percentage = (fraction * 100).round();
        final bool hasActivePlan = snapshot.data != null;
        final String daysLabel = progress.totalDays > 0
            ? '${progress.completedDays}/${progress.totalDays} days completed'
            : 'No active plan — tap to view workout plan';

        return Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: hasActivePlan ? onTapWithPlan : onTapNoPlan,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _withOpacity(Colors.black, 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: progress.totalDays > 0 ? fraction : 0,
                            strokeWidth: 14,
                            strokeCap: StrokeCap.round,
                            backgroundColor: _withOpacity(primaryColor, 0.14),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryColor,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$percentage%',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Completed',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: _withOpacity(textColor, 0.72),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    daysLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
