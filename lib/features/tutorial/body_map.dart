import 'package:flutter/material.dart';

import 'muscle_models.dart';
import 'muscle_regions.dart';

class BodyMap extends StatefulWidget {
  const BodyMap({
    super.key,
    required this.side,
    required this.primaryColor,
    required this.selected,
    required this.onSelected,
  });

  final BodySide side;
  final Color primaryColor;
  final MuscleId? selected;
  final ValueChanged<MuscleId?> onSelected;

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> {
  bool _pressed = false;

  String get _asset {
    switch (widget.side) {
      case BodySide.front:
        return 'assets/Male_Front_Model.png';
      case BodySide.back:
        return 'assets/Male_Back_Model.png';
    }
  }

  void _handleTap(Offset localPos, Size size) {
    final List<MuscleRegion> regions = MuscleRegions.forSide(widget.side);
    for (final MuscleRegion r in regions) {
      if (r.hitTest(localPos, size)) {
        widget.onSelected(r.id);
        return;
      }
    }
    widget.onSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    final Color highlightColor = widget.primaryColor.withValues(alpha: 0.3);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (TapUpDetails d) {
            setState(() => _pressed = false);
            _handleTap(d.localPosition, size);
          },
          child: AnimatedScale(
            scale: _pressed ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _asset,
                  fit: BoxFit.contain,
                ),
                Positioned.fill(
                  child: _HighlightOverlay(
                    side: widget.side,
                    selected: widget.selected,
                    color: highlightColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HighlightOverlay extends StatelessWidget {
  const _HighlightOverlay({
    required this.side,
    required this.selected,
    required this.color,
  });

  final BodySide side;
  final MuscleId? selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: selected == null ? 0 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _HighlightPainter(
            side: side,
            selected: selected,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter({
    required this.side,
    required this.selected,
    required this.color,
  });

  final BodySide side;
  final MuscleId? selected;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (selected == null) return;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final List<MuscleRegion> regions = MuscleRegions.forSide(side);
    final Iterable<MuscleRegion> matches =
        regions.where((MuscleRegion r) => r.id == selected);

    for (final MuscleRegion r in matches) {
      canvas.drawPath(r.pathBuilder(size), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return oldDelegate.side != side ||
        oldDelegate.selected != selected ||
        oldDelegate.color != color;
  }
}

