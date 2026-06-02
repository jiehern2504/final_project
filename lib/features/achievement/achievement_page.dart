import 'package:flutter/material.dart';

import '../planner/workout_plan_models.dart';
import '../planner/workout_plan_repository.dart';

const Color _kPrimaryColor = Color(0xFF4CAF50);
const Color _kSecondaryColor = Color(0xFFFFB74D);

class AchievementPage extends StatelessWidget {
  const AchievementPage({super.key, this.repository});

  final WorkoutPlanRepository? repository;

  @override
  Widget build(BuildContext context) {
    final WorkoutPlanRepository repo =
        repository ?? WorkoutPlanRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('Achievements'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<WorkoutPlan?>(
          stream: repo.watchActivePlan(),
          builder: (BuildContext context, AsyncSnapshot<WorkoutPlan?> snapshot) {
            final PlanProgress progress =
                snapshot.data?.progress ?? const PlanProgress(
                  completedDays: 0,
                  totalDays: 0,
                );
            final int completed = progress.completedDays;
            final List<_Badge> badges = _badgesFor(completed);

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: [
                _StreakCard(completedDays: completed),
                const SizedBox(height: 20),
                Text(
                  'Badges',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                ...badges.map(
                  (_Badge badge) => _BadgeTile(badge: badge),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static List<_Badge> _badgesFor(int completedDays) {
    return <_Badge>[
      _Badge(
        title: 'First step',
        subtitle: 'Complete your first training day',
        icon: Icons.emoji_events_outlined,
        unlocked: completedDays >= 1,
        color: _kSecondaryColor,
      ),
      _Badge(
        title: 'On a roll',
        subtitle: 'Finish 3 training days',
        icon: Icons.local_fire_department_outlined,
        unlocked: completedDays >= 3,
        color: _kPrimaryColor,
      ),
      _Badge(
        title: 'Week warrior',
        subtitle: 'Finish 5 training days',
        icon: Icons.military_tech_outlined,
        unlocked: completedDays >= 5,
        color: const Color(0xFF5C6BC0),
      ),
      _Badge(
        title: 'Plan finisher',
        subtitle: 'Complete every day in your plan',
        icon: Icons.workspace_premium_outlined,
        unlocked: completedDays >= 7,
        color: const Color(0xFF8E24AA),
      ),
    ];
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.completedDays});

  final int completedDays;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _kSecondaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: _kSecondaryColor,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$completedDays day streak',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on completed plan days — separate from daily checklist.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge {
  const _Badge({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unlocked,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool unlocked;
  final Color color;
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: badge.unlocked
              ? badge.color.withValues(alpha: 0.2)
              : Colors.grey.shade200,
          child: Icon(
            badge.icon,
            color: badge.unlocked ? badge.color : Colors.grey,
          ),
        ),
        title: Text(
          badge.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: badge.unlocked ? null : Colors.grey,
          ),
        ),
        subtitle: Text(badge.subtitle),
        trailing: Icon(
          badge.unlocked ? Icons.check_circle : Icons.lock_outline,
          color: badge.unlocked ? _kPrimaryColor : Colors.grey,
        ),
      ),
    );
  }
}

//testing