import 'package:flutter/material.dart';

import 'summary_chart.dart';
import 'summary_models.dart';

const Color _kPrimary = Color(0xFF4CAF50);
const Color _kBg = Color(0xFFF9FBF9);
const Color _kText = Color(0xFF333333);
const Color _kMuted = Color(0xFF7A8A80);
const Color _kChip = Color(0xFFEEF5F0);

enum _Level { month, year }

/// Full progress view opened from the Home summary card. Month and Year only
/// (no week — weight isn't recorded daily), with drill-down from year → month.
class SummaryDetailPage extends StatefulWidget {
  const SummaryDetailPage({super.key, required this.data});

  final SummaryData data;

  @override
  State<SummaryDetailPage> createState() => _SummaryDetailPageState();
}

class _SummaryDetailPageState extends State<SummaryDetailPage> {
  _Level _level = _Level.month;
  late DateTime _anchor;
  late final DateTime _today;
  late final DateTime _dataStart;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _anchor = DateTime(_today.year, _today.month, _today.day);
    _dataStart = _earliestLog();
  }

  DateTime _earliestLog() {
    DateTime? earliest;
    if (widget.data.weights.isNotEmpty) earliest = widget.data.weights.first.at;
    if (widget.data.workouts.isNotEmpty) {
      final DateTime w = widget.data.workouts.first.at;
      if (earliest == null || w.isBefore(earliest)) earliest = w;
    }
    return earliest ?? _today;
  }

  List<ChartPoint> _points() => _level == _Level.year
      ? widget.data.yearPoints(_anchor, today: _today)
      : widget.data.monthPoints(_anchor, today: _today);

  String _periodLabel() => _level == _Level.year
      ? '${_anchor.year}'
      : '${SummaryData.months[_anchor.month - 1]} ${_anchor.year}';

  DateTime _step(DateTime d, int dir) => _level == _Level.year
      ? DateTime(d.year + dir, d.month, d.day)
      : DateTime(d.year, d.month + dir, 1);

  bool _canShift(int dir) {
    final DateTime x = _step(_anchor, dir);
    if (dir > 0) {
      return _level == _Level.year
          ? x.year <= _today.year
          : !x.isAfter(DateTime(_today.year, _today.month, 1));
    }
    return _level == _Level.year
        ? x.year >= _dataStart.year
        : !x.isBefore(DateTime(_dataStart.year, _dataStart.month, 1));
  }

  void _shift(int dir) {
    if (_canShift(dir)) setState(() => _anchor = _step(_anchor, dir));
  }

  @override
  Widget build(BuildContext context) {
    final List<ChartPoint> points = _points();
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Progress details'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _rangeToggle(),
            const SizedBox(height: 14),
            _navRow(),
            const SizedBox(height: 6),
            _legend(),
            const SizedBox(height: 4),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE6EFE8)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                child: points.isEmpty
                    ? const SizedBox(
                        height: 180,
                        child: Center(
                          child: Text('No data for this period.',
                              style: TextStyle(color: _kMuted)),
                        ),
                      )
                    : SummaryChart(
                        points: points,
                        showAxes: true,
                        height: 210,
                        onPointTap: _level == _Level.year
                            ? (int i) => _drillToMonth(points, i)
                            : null,
                      ),
              ),
            ),
            if (points.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _level == _Level.year
                      ? 'Tap a month to open it'
                      : 'Monthly view',
                  style: const TextStyle(fontSize: 11, color: _kMuted),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _details(points),
          ],
        ),
      ),
    );
  }

  void _drillToMonth(List<ChartPoint> points, int i) {
    final DateTime? d = points[i].date;
    if (d == null) return;
    setState(() {
      _level = _Level.month;
      _anchor = DateTime(d.year, d.month, 1);
    });
  }

  Widget _rangeToggle() {
    return SegmentedButton<_Level>(
      segments: const <ButtonSegment<_Level>>[
        ButtonSegment<_Level>(value: _Level.month, label: Text('Month')),
        ButtonSegment<_Level>(value: _Level.year, label: Text('Year')),
      ],
      selected: <_Level>{_level},
      onSelectionChanged: (Set<_Level> s) => setState(() => _level = s.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> st) =>
              st.contains(WidgetState.selected) ? _kPrimary : _kChip,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> st) =>
              st.contains(WidgetState.selected) ? Colors.white : _kMuted,
        ),
      ),
    );
  }

  Widget _navRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _breadcrumb(),
        Row(
          children: [
            _iconBtn(Icons.chevron_left, _canShift(-1) ? () => _shift(-1) : null),
            SizedBox(
              width: 104,
              child: Text(
                _periodLabel(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _kText),
              ),
            ),
            _iconBtn(Icons.chevron_right, _canShift(1) ? () => _shift(1) : null),
          ],
        ),
      ],
    );
  }

  Widget _breadcrumb() {
    final List<Widget> parts = <Widget>[
      GestureDetector(
        onTap: _level == _Level.year
            ? null
            : () => setState(() => _level = _Level.year),
        child: Text(
          '${_anchor.year}',
          style: TextStyle(
            fontSize: 12,
            color: _level == _Level.year ? _kText : _kMuted,
            fontWeight:
                _level == _Level.year ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ];
    if (_level == _Level.month) {
      parts.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Text('▸', style: TextStyle(fontSize: 11, color: _kMuted)),
      ));
      parts.add(Text(
        SummaryData.months[_anchor.month - 1],
        style: const TextStyle(
            fontSize: 12, color: _kText, fontWeight: FontWeight.w700),
      ));
    }
    return Row(children: parts);
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE6EFE8)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: _kText),
        ),
      ),
    );
  }

  Widget _legend() {
    return Row(
      children: const [
        _Key(color: SummaryChart.weightColor, label: 'Weight (kg)'),
        SizedBox(width: 16),
        _Key(color: SummaryChart.workoutColor, label: 'Workouts done'),
      ],
    );
  }

  Widget _details(List<ChartPoint> points) {
    final PeriodSummary s = widget.data.summarize(points);
    final String deltaTxt = s.hasWeight
        ? '${s.weightDelta > 0 ? '+' : ''}${s.weightDelta.toStringAsFixed(1)} kg'
        : '—';
    final Color deltaColor = !s.hasWeight
        ? _kMuted
        : (s.weightDelta <= 0 ? SummaryChart.weightColor : const Color(0xFFD9803F));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_level == _Level.year ? 'This year' : 'This month'} · ${_periodLabel()}',
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _stat('Weight change', deltaTxt, deltaColor),
            const SizedBox(width: 10),
            _stat('Workouts', '${s.totalWorkouts}', _kText),
            const SizedBox(width: 10),
            _stat('Total sets', '${s.totalSets}', _kText),
          ],
        ),
        const SizedBox(height: 12),
        ..._detailList(points),
      ],
    );
  }

  List<Widget> _detailList(List<ChartPoint> points) {
    if (_level == _Level.month) {
      final List<WorkoutLog> sessions = widget.data.sessionsInMonth(_anchor);
      if (sessions.isEmpty) {
        return const <Widget>[
          _RowLine(left: 'No workouts logged', right: ''),
        ];
      }
      return sessions
          .map((WorkoutLog w) => _RowLine(
                left: '${SummaryData.months[w.at.month - 1]} ${w.at.day}',
                right: '${w.title} · ${w.sets} sets',
                pill: true,
              ))
          .toList();
    }
    // year view: one row per month
    return points
        .map((ChartPoint p) => _RowLine(
              left:
                  '${p.label} · ${p.weight != null ? '${p.weight!.toStringAsFixed(1)} kg' : '—'}',
              right: '${p.metric} workouts · ${p.sets} sets',
            ))
        .toList();
  }

  Widget _stat(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _kChip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10, color: _kMuted, letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: valueColor)),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: _kMuted)),
      ],
    );
  }
}

class _RowLine extends StatelessWidget {
  const _RowLine({required this.left, required this.right, this.pill = false});

  final String left;
  final String right;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE6EFE8))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(left,
                style: const TextStyle(fontSize: 13, color: _kText)),
          ),
          const SizedBox(width: 8),
          if (right.isNotEmpty)
            pill
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(right,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary)),
                  )
                : Text(right,
                    style: const TextStyle(fontSize: 12, color: _kMuted)),
        ],
      ),
    );
  }
}
