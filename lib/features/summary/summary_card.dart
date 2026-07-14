import 'package:flutter/material.dart';

import 'summary_detail_page.dart';
import 'summary_models.dart';
import 'summary_chart.dart';
import 'summary_repository.dart';
import '../../core/theme/app_colors.dart';

const Color _kPrimary = AppColors.primary;
const Color _kText = AppColors.text;
const Color _kMuted = AppColors.muted;

/// The "Your progress" summary card shown at the bottom of the Home page.
/// Shows the current month's weight + workouts; tapping opens the detail view.
class SummaryCard extends StatefulWidget {
  const SummaryCard({super.key, this.repository});

  final SummaryRepository? repository;

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  late final SummaryRepository _repo;
  late Future<SummaryData> _future;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? SummaryRepository();
    _future = _repo.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SummaryData>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<SummaryData> snap) {
        final SummaryData data =
            snap.data ?? SummaryData(weights: <WeightLog>[], workouts: <WorkoutLog>[]);
        final bool loading =
            snap.connectionState == ConnectionState.waiting && !snap.hasData;
        final DateTime now = DateTime.now();
        final List<ChartPoint> points = data.monthPoints(now, today: now);

        return _CardShell(
          onTap: (loading || data.isEmpty)
              ? null
              : () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => SummaryDetailPage(data: data),
                    ),
                  ),
          child: loading
              ? const SizedBox(
                  height: 150,
                  child: Center(child: CircularProgressIndicator()),
                )
              : data.isEmpty
                  ? _empty()
                  : _content(context, points, now),
        );
      },
    );
  }

  Widget _content(BuildContext context, List<ChartPoint> points, DateTime now) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kText,
                    ),
                  ),
                  Text(
                    'This month · ${SummaryData.months[now.month - 1]} ${now.year}',
                    style: const TextStyle(fontSize: 12, color: _kMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _kMuted),
          ],
        ),
        const SizedBox(height: 12),
        _MiniChart(
          label: 'Weight (kg)',
          color: SummaryChart.weightColor,
          points: points,
          metric: SummaryMetric.weight,
          emptyText: 'No weight logged yet',
        ),
        const SizedBox(height: 14),
        _MiniChart(
          label: 'Workouts done',
          color: SummaryChart.workoutColor,
          points: points,
          metric: SummaryMetric.workouts,
          emptyText: 'No workouts yet',
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Tap to see details ›',
            style: TextStyle(
              fontSize: 12,
              color: _kPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your progress',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _kText,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.insights_outlined, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Complete workouts and update your weight to see your progress chart here.',
                style: TextStyle(fontSize: 13, color: _kMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
          child: child,
        ),
      ),
    );
  }
}

/// A labelled single-metric mini chart used on the Home card.
class _MiniChart extends StatelessWidget {
  const _MiniChart({
    required this.label,
    required this.color,
    required this.points,
    required this.metric,
    required this.emptyText,
  });

  final String label;
  final Color color;
  final List<ChartPoint> points;
  final SummaryMetric metric;
  final String emptyText;

  bool get _hasData => metric == SummaryMetric.weight
      ? points.any((ChartPoint p) => p.weight != null)
      : points.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
          ],
        ),
        const SizedBox(height: 2),
        if (_hasData)
          SummaryChart(
            points: points,
            metric: metric,
            showAxes: false,
            height: 92,
          )
        else
          SizedBox(
            height: 92,
            child: Center(
              child: Text(emptyText,
                  style: const TextStyle(fontSize: 12, color: _kMuted)),
            ),
          ),
      ],
    );
  }
}
