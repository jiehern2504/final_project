import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class BearMascot extends StatelessWidget {
  const BearMascot({super.key, this.size = 130});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BearPainter()),
    );
  }
}

class _BearPainter extends CustomPainter {
  static const Color _white = Colors.white;
  static const Color _orange = AppColors.secondary;
  static const Color _coral = Color(0xFFF0897A);
  static const Color _dark = AppColors.text;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 120.0;
    Offset p(double x, double y) => Offset(x * s, y * s);
    double r(double v) => v * s;

    final Paint fillWhite = Paint()..color = _white;
    final Paint fillOrange = Paint()..color = _orange;
    final Paint fillCoral = Paint()..color = _coral;
    final Paint fillDark = Paint()..color = _dark;
    final Paint stroke = Paint()
      ..color = _orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = r(3);

    for (final double cx in <double>[34, 86]) {
      canvas.drawCircle(p(cx, 34), r(15), fillWhite);
      canvas.drawCircle(p(cx, 34), r(15), stroke);
      canvas.drawCircle(p(cx, 34), r(7), fillOrange);
    }

    final Rect body = Rect.fromCenter(
      center: p(60, 70),
      width: r(82),
      height: r(86),
    );
    canvas.drawOval(body, fillWhite);
    canvas.drawOval(body, stroke);

    final RRect band = RRect.fromRectAndRadius(
      Rect.fromLTWH(r(24), r(48), r(72), r(13)),
      Radius.circular(r(6)),
    );
    canvas.drawRRect(band, fillCoral);

    canvas.drawCircle(p(49, 72), r(3.5), fillDark);
    canvas.drawCircle(p(71, 72), r(3.5), fillDark);

    canvas.drawOval(
      Rect.fromCenter(center: p(60, 86), width: r(34), height: r(24)),
      fillOrange,
    );
    canvas.drawCircle(p(60, 81), r(3.5), fillDark);
    canvas.drawLine(
      p(60, 84),
      p(60, 90),
      Paint()
        ..color = _dark
        ..strokeWidth = r(2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
