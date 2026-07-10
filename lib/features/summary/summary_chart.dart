import 'package:flutter/material.dart';

import 'summary_models.dart';

/// A two-line chart: body weight (teal) and workouts completed (green).
///
/// Set [showAxes] false for the compact Home card. Pass [onPointTap] to make
/// points tappable (used to drill from a year into a month).
class SummaryChart extends StatelessWidget {
  const SummaryChart({
    super.key,
    required this.points,
    this.showAxes = true,
    this.height = 210,
    this.onPointTap,
  });

  final List<ChartPoint> points;
  final bool showAxes;
  final double height;
  final void Function(int index)? onPointTap;

  static const Color weightColor = Color(0xFF2AA6A6);
  static const Color workoutColor = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final _SummaryPainter painter = _SummaryPainter(
          points: points,
          showAxes: showAxes,
          weightColor: weightColor,
          workoutColor: workoutColor,
        );
        final Widget chart = CustomPaint(
          size: Size(w, height),
          painter: painter,
        );
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
    required this.showAxes,
    required this.weightColor,
    required this.workoutColor,
  });

  final List<ChartPoint> points;
  final bool showAxes;
  final Color weightColor;
  final Color workoutColor;

  static const Color _muted = Color(0xFF7A8A80);
  static const Color _grid = Color(0x14333333);
  static const Color _cardFill = Colors.white;

  double get _padL => showAxes ? 32 : 8;
  double get _padR => showAxes ? 30 : 8;
  double get _padT => 12;
  double get _padB => showAxes ? 22 : 10;

  double _x(int i, double plotW) => points.length == 1
      ? _padL + plotW / 2
      : _padL + plotW * i / (points.length - 1);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final double plotW = size.width - _padL - _padR;
    final double plotH = size.height - _padT - _padB;

    final List<double> ws = <double>[
      for (final ChartPoint p in points)
        if (p.weight != null) p.weight!,
    ];
    final bool hasWeight = ws.isNotEmpty;
    double wMin = hasWeight ? ws.reduce((a, b) => a < b ? a : b) : 0;
    double wMax = hasWeight ? ws.reduce((a, b) => a > b ? a : b) : 1;
    if (wMin == wMax) {
      wMin -= 1;
      wMax += 1;
    }
    final double wpad = (wMax - wMin) * 0.3 + 0.2;
    wMin -= wpad;
    wMax += wpad;

    int kMax = 2;
    for (final ChartPoint p in points) {
      if (p.metric > kMax) kMax = p.metric;
    }

    double yW(double v) => _padT + plotH * (1 - (v - wMin) / (wMax - wMin));
    double yK(num v) => _padT + plotH * (1 - v / kMax);

    final Paint gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    final int rows = showAxes ? 4 : 3;
    for (int r = 0; r <= rows; r++) {
      final double y = _padT + plotH * r / rows;
      canvas.drawLine(Offset(_padL, y), Offset(size.width - _padR, y), gridPaint);
      if (showAxes) {
        if (hasWeight) {
          _text(canvas, (wMax - (wMax - wMin) * r / rows).toStringAsFixed(0),
              Offset(_padL - 6, y), align: TextAlign.right, anchorRight: true);
        }
        _text(canvas, (kMax - kMax * r / rows).round().toString(),
            Offset(size.width - _padR + 6, y), align: TextAlign.left);
      }
    }

    if (showAxes) {
      final int step = (points.length / 7).ceil().clamp(1, 999);
      for (int i = 0; i < points.length; i++) {
        if (i % step == 0 || i == points.length - 1) {
          _text(canvas, points[i].label,
              Offset(_x(i, plotW), size.height - _padB + 3),
              align: TextAlign.center, anchorTop: true);
        }
      }
    }

    // Weight line — draw across runs of non-null values.
    final Paint wLine = Paint()
      ..color = weightColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    Path? seg;
    for (int i = 0; i < points.length; i++) {
      final double? v = points[i].weight;
      if (v == null) {
        if (seg != null) {
          canvas.drawPath(seg, wLine);
          seg = null;
        }
        continue;
      }
      final Offset pt = Offset(_x(i, plotW), yW(v));
      if (seg == null) {
        seg = Path()..moveTo(pt.dx, pt.dy);
      } else {
        seg.lineTo(pt.dx, pt.dy);
      }
    }
    if (seg != null) canvas.drawPath(seg, wLine);

    // Workouts line.
    final Paint kLine = Paint()
      ..color = workoutColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final Path kPath = Path();
    for (int i = 0; i < points.length; i++) {
      final Offset pt = Offset(_x(i, plotW), yK(points[i].metric));
      if (i == 0) {
        kPath.moveTo(pt.dx, pt.dy);
      } else {
        kPath.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(kPath, kLine);

    // Dots (only when the series is short enough to read).
    if (points.length <= 14) {
      for (int i = 0; i < points.length; i++) {
        final double x = _x(i, plotW);
        if (points[i].weight != null) {
          _dot(canvas, Offset(x, yW(points[i].weight!)), weightColor);
        }
        _dot(canvas, Offset(x, yK(points[i].metric)), workoutColor);
      }
    }
  }

  void _dot(Canvas canvas, Offset c, Color color) {
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

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    TextAlign align = TextAlign.left,
    bool anchorRight = false,
    bool anchorTop = false,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    double dx = at.dx;
    double dy = at.dy;
    if (align == TextAlign.center) dx -= tp.width / 2;
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
      old.points != points || old.showAxes != showAxes;
}
