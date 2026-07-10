import 'package:flutter/material.dart';

import 'summary_detail_page.dart';
import 'summary_models.dart';
import 'summary_chart.dart';
import 'summary_repository.dart';

const Color _kPrimary = Color(0xFF4CAF50);
const Color _kText = Color(0xFF333333);
const Color _kMuted = Color(0xFF7A8A80);

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
        const SizedBox(height: 8),
        const _Legend(),
        const SizedBox(height: 4),
        SummaryChart(points: points, showAxes: false, height: 128),
        const SizedBox(height: 6),
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
            border: Border.all(color: const Color(0xFFE6EFE8)),
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LegendKey(color: SummaryChart.weightColor, label: 'Weight (kg)'),
        SizedBox(width: 16),
        _LegendKey(color: SummaryChart.workoutColor, label: 'Workouts done'),
      ],
    );
  }
}

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: _kMuted)),
      ],
    );
  }
}
