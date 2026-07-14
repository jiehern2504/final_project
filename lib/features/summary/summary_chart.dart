import 'package:flutter/material.dart';

import 'summary_models.dart';

/// Which single series a [SummaryChart] draws.
enum SummaryMetric { weight, workouts }

/// A single-line chart of one metric — body weight (teal) OR workouts
/// completed (green). Weight and workouts are shown as two separate charts.
class SummaryChart extends StatelessWidget {
  const SummaryChart({
    super.key,
    required this.points,
    required this.metric,
    this.showAxes = true,
    this.height = 160,
    this.onPointTap,
  });

  final List<ChartPoint> points;
  final SummaryMetric metric;
  final bool showAxes;
  final double height;
  final void Function(int index)? onPointTap;

  static const Color weightColor = Color(0xFF2AA6A6);
  static const Color workoutColor = Color(0xFF4CAF50);

  Color get _color =>
      metric == SummaryMetric.weight ? weightColor : workoutColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final _SummaryPainter painter = _SummaryPainter(
          points: points,
          metric: metric,
          showAxes: showAxes,
          color: _color,
        );
        final Widget chart = CustomPaint(size: Size(w, height), painter: painter);
        if (onPointTap == null) {
          return SizedBox(width: w, height: height, child: chart);
        }
        return GestureDetector(
          onTapUp: (TapUpDetails d) {
            final int? i = painter.indexAt(d.localPosition.dx, w);
            if (i != null) onPointTap!(i);
          },
          child: SizedBox(width: w, height: height, child: chart),
        );
      },
    );
  }
}

class _SummaryPainter extends CustomPainter {
  _SummaryPainter({
    required this.points,
    required this.metric,
    required this.showAxes,
    required this.color,
  });

  final List<ChartPoint> points;
  final SummaryMetric metric;
  final bool showAxes;
  final Color color;

  static const Color _muted = Color(0xFF7A8A80);
  static const Color _grid = Color(0x14333333);
  static const Color _cardFill = Colors.white;

  double get _padL => showAxes ? 32 : 8;
  double get _padR => showAxes ? 12 : 8;
  double get _padT => 12;
  double get _padB => showAxes ? 22 : 10;

  /// The value for this metric at [p]; null only for missing weight readings.
  double? _value(ChartPoint p) =>
      metric == SummaryMetric.weight ? p.weight : p.metric.toDouble();

  double _x(int i, double plotW) => points.length == 1
      ? _padL + plotW / 2
      : _padL + plotW * i / (points.length - 1);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final double plotW = size.width - _padL - _padR;
    final double plotH = size.height - _padT - _padB;

    final List<double> vals = <double>[
      for (final ChartPoint p in points)
        if (_value(p) != null) _value(p)!,
    ];
    if (vals.isEmpty) return; // e.g. no weight readings in this period

    double vMin;
    double vMax;
    if (metric == SummaryMetric.weight) {
      vMin = vals.reduce((a, b) => a < b ? a : b);
      vMax = vals.reduce((a, b) => a > b ? a : b);
      if (vMin == vMax) {
        vMin -= 1;
        vMax += 1;
      }
      final double pad = (vMax - vMin) * 0.3 + 0.2;
      vMin -= pad;
      vMax += pad;
    } else {
      vMin = 0;
      vMax = vals.reduce((a, b) => a > b ? a : b);
      if (vMax < 2) vMax = 2;
    }

    double y(double v) => _padT + plotH * (1 - (v - vMin) / (vMax - vMin));

    // Grid + left-axis labels.
    final Paint gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    final int rows = showAxes ? 4 : 3;
    for (int r = 0; r <= rows; r++) {
      final double yy = _padT + plotH * r / rows;
      canvas.drawLine(Offset(_padL, yy), Offset(size.width - _padR, yy), gridPaint);
      if (showAxes) {
        final double v = vMax - (vMax - vMin) * r / rows;
        final String label = metric == SummaryMetric.weight
            ? v.toStringAsFixed(0)
            : v.round().toString();
        _text(canvas, label, Offset(_padL - 6, yy), anchorRight: true);
      }
    }

    // X-axis labels.
    if (showAxes) {
      final int step = (points.length / 7).ceil().clamp(1, 999);
      for (int i = 0; i < points.length; i++) {
        if (i % step == 0 || i == points.length - 1) {
          _text(canvas, points[i].label,
              Offset(_x(i, plotW), size.height - _padB + 3),
              anchorTop: true, center: true);
        }
      }
    }

    // Line — weight can have gaps (missing readings) → draw in segments.
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    Path? seg;
    for (int i = 0; i < points.length; i++) {
      final double? v = _value(points[i]);
      if (v == null) {
        if (seg != null) {
          canvas.drawPath(seg, linePaint);
          seg = null;
        }
        continue;
      }
      final Offset pt = Offset(_x(i, plotW), y(v));
      if (seg == null) {
        seg = Path()..moveTo(pt.dx, pt.dy);
      } else {
        seg.lineTo(pt.dx, pt.dy);
      }
    }
    if (seg != null) canvas.drawPath(seg, linePaint);

    // Dots (only when the series is short enough to read).
    if (points.length <= 14) {
      for (int i = 0; i < points.length; i++) {
        final double? v = _value(points[i]);
        if (v == null) continue;
        final Offset c = Offset(_x(i, plotW), y(v));
        canvas.drawCircle(c, 4, Paint()..color = _cardFill);
        canvas.drawCircle(
          c,
          4,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    bool anchorRight = false,
    bool anchorTop = false,
    bool center = false,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx = at.dx;
    double dy = at.dy;
    if (center) dx -= tp.width / 2;
    if (anchorRight) dx -= tp.width;
    if (!anchorTop) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  /// Nearest point index to a horizontal tap position.
  int? indexAt(double dx, double width) {
    if (points.isEmpty) return null;
    final double plotW = width - _padL - _padR;
    int best = 0;
    double bd = double.infinity;
    for (int i = 0; i < points.length; i++) {
      final double d = (_x(i, plotW) - dx).abs();
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  @override
  bool shouldRepaint(covariant _SummaryPainter old) =>
      old.points != points ||
      old.showAxes != showAxes ||
      old.metric != metric;
}
