import 'package:flutter/material.dart';

import '../planner/repositories/workout_plan_repository.dart';
import '../summary/summary_repository.dart';

const Color _kPrimaryColor = Color(0xFF4CAF50);
const Color _kSecondaryColor = Color(0xFFFFB74D);

/// Aggregated achievement inputs: lifetime completed workout days (never resets,
/// even across weeks/plans) + whether a full 4-week plan was ever finished.
class _AchievementData {
  const _AchievementData({required this.totalWorkouts, required this.monthDone});
  final int totalWorkouts;
  final bool monthDone;
}

class AchievementPage extends StatefulWidget {
  const AchievementPage({super.key, this.repository, this.summaryRepository});

  final WorkoutPlanRepository? repository;
  final SummaryRepository? summaryRepository;

  @override
  State<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends State<AchievementPage> {
  late final WorkoutPlanRepository _repo;
  late final SummaryRepository _summary;
  late Future<_AchievementData> _future;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? WorkoutPlanRepository();
    _summary = widget.summaryRepository ?? SummaryRepository();
    _future = _load();
  }

  Future<_AchievementData> _load() async {
    final int total = (await _summary.load()).workouts.length;
    final bool month = await _repo.hasCompletedFourWeekPlan();
    return _AchievementData(totalWorkouts: total, monthDone: month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(title: const Text('Achievements'), centerTitle: true),
      body: SafeArea(
        child: FutureBuilder<_AchievementData>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<_AchievementData> snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final _AchievementData data =
                snap.data ?? const _AchievementData(totalWorkouts: 0, monthDone: false);
            final List<_Badge> badges =
                _badgesFor(data.totalWorkouts, data.monthDone);
            final int unlocked = badges.where((b) => b.unlocked).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: [
                _TotalCard(totalWorkouts: data.totalWorkouts),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Badges',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '$unlocked / ${badges.length} unlocked',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...badges.map((_Badge badge) => _BadgeTile(badge: badge)),
              ],
            );
          },
        ),
      ),
    );
  }

  static List<_Badge> _badgesFor(int total, bool monthDone) {
    return <_Badge>[
      _Badge(
        title: 'First Step',
        subtitle: 'Complete your first training day',
        icon: Icons.emoji_events_outlined,
        unlocked: total >= 1,
        color: _kSecondaryColor,
        progressLabel: '$total / 1',
      ),
      _Badge(
        title: 'On a Roll',
        subtitle: 'Finish 3 training days',
        icon: Icons.local_fire_department_outlined,
        unlocked: total >= 3,
        color: _kPrimaryColor,
        progressLabel: '$total / 3',
      ),
      _Badge(
        title: 'Week Warrior',
        subtitle: 'Finish 7 training days',
        icon: Icons.military_tech_outlined,
        unlocked: total >= 7,
        color: const Color(0xFF5C6BC0),
        progressLabel: '$total / 7',
      ),
      _Badge(
        title: 'Fortnight Fighter',
        subtitle: 'Finish 14 training days',
        icon: Icons.bolt_outlined,
        unlocked: total >= 14,
        color: const Color(0xFF00897B),
        progressLabel: '$total / 14',
      ),
      _Badge(
        title: 'Month Master',
        subtitle: 'Complete a full 4-week plan',
        icon: Icons.workspace_premium_outlined,
        unlocked: monthDone,
        color: const Color(0xFF8E24AA),
        progressLabel: monthDone ? 'Done' : 'Locked',
      ),
      _Badge(
        title: 'Unstoppable',
        subtitle: 'Finish 50 training days',
        icon: Icons.diamond_outlined,
        unlocked: total >= 50,
        color: const Color(0xFFD81B60),
        progressLabel: '$total / 50',
      ),
    ];
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.totalWorkouts});

  final int totalWorkouts;

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
                    '$totalWorkouts workouts completed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total training days you\'ve finished — keeps growing across '
                    'every plan and every month.',
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
    required this.progressLabel,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool unlocked;
  final Color color;
  final String progressLabel;
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
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(
              badge.unlocked ? Icons.check_circle : Icons.lock_outline,
              color: badge.unlocked ? _kPrimaryColor : Colors.grey,
            ),
            const SizedBox(height: 2),
            Text(
              badge.progressLabel,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
