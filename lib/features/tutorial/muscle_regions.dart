import 'package:flutter/material.dart';

import 'muscle_models.dart';

Path _rectN(Size size, Rect nRect) {
  return Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          nRect.left * size.width,
          nRect.top * size.height,
          nRect.width * size.width,
          nRect.height * size.height,
        ),
        Radius.circular(size.shortestSide * 0.04),
      ),
    );
}

/// Like [_rectN] but rotated around its own centre by [angleRadians], so the
/// rounded bar can follow the natural (slightly splayed) direction of a limb.
/// Positive angle tilts the bottom of the bar to the LEFT.
Path _tiltedRectN(Size size, Rect nRect, double angleRadians) {
  final Rect r = Rect.fromLTWH(
    nRect.left * size.width,
    nRect.top * size.height,
    nRect.width * size.width,
    nRect.height * size.height,
  );
  final Path p = Path()
    ..addRRect(
      RRect.fromRectAndRadius(r, Radius.circular(size.shortestSide * 0.04)),
    );
  final Offset c = r.center;
  final Matrix4 m = Matrix4.translationValues(c.dx, c.dy, 0)
    ..multiply(Matrix4.rotationZ(angleRadians))
    ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0));
  return p.transform(m.storage);
}

/// How much the arm highlight bars lean outward (~22°), to follow the arms.
const double _kArmTiltRad = 0.38;

Path _polyN(Size size, List<Offset> nPoints) {
  final Path p = Path();
  for (int i = 0; i < nPoints.length; i++) {
    final Offset pt = Offset(
      nPoints[i].dx * size.width,
      nPoints[i].dy * size.height,
    );
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  p.close();
  return p;
}

/// Muscle regions are *approximate* overlays on the supplied silhouette images.
/// They are normalized to the image bounds (0..1).
class MuscleRegions {
  static List<MuscleRegion> forSide(BodySide side) {
    switch (side) {
      case BodySide.front:
        return _front;
      case BodySide.back:
        return _back;
    }
  }

  static final List<MuscleRegion> _front = <MuscleRegion>[
    // Arms (left + right)
    MuscleRegion(
      id: MuscleId.arms,
      side: BodySide.front,
      pathBuilder: (Size s) => Path.combine(
        PathOperation.union,
        // left arm tilts bottom outward (left), right arm outward (right)
        _tiltedRectN(s, const Rect.fromLTWH(0.16, 0.23, 0.12, 0.28), _kArmTiltRad),
        _tiltedRectN(s, const Rect.fromLTWH(0.75, 0.23, 0.12, 0.28), -_kArmTiltRad),
      ),
    ),
    MuscleRegion(
      id: MuscleId.shoulders,
      side: BodySide.front,
      pathBuilder: (Size s) => Path.combine(
        PathOperation.union,
        _rectN(s, const Rect.fromLTWH(0.23, 0.15, 0.16, 0.10)),
        _rectN(s, const Rect.fromLTWH(0.61, 0.15, 0.16, 0.10)),
      ),
    ),
    MuscleRegion(
      id: MuscleId.chest,
      side: BodySide.front,
      pathBuilder: (Size s) => _polyN(
        s,
        const <Offset>[
          Offset(0.38, 0.18),
          Offset(0.62, 0.18),
          Offset(0.68, 0.28),
          Offset(0.32, 0.28),
        ],
      ),
    ),
    MuscleRegion(
      id: MuscleId.abs,
      side: BodySide.front,
      pathBuilder: (Size s) => _rectN(
        s,
        const Rect.fromLTWH(0.42, 0.28, 0.16, 0.20),
      ),
    ),
    MuscleRegion(
      id: MuscleId.legs,
      side: BodySide.front,
      pathBuilder: (Size s) => Path.combine(
        PathOperation.union,
        _rectN(s, const Rect.fromLTWH(0.33, 0.48, 0.15, 0.40)),
        _rectN(s, const Rect.fromLTWH(0.54, 0.48, 0.15, 0.40)),
      ),
    ),
  ];

  static final List<MuscleRegion> _back = <MuscleRegion>[
    MuscleRegion(
      id: MuscleId.arms,
      side: BodySide.back,
      pathBuilder: (Size s) => Path.combine(
        PathOperation.union,
        _tiltedRectN(s, const Rect.fromLTWH(0.14, 0.23, 0.13, 0.28), _kArmTiltRad),
        _tiltedRectN(s, const Rect.fromLTWH(0.73, 0.23, 0.13, 0.28), -_kArmTiltRad),
      ),
    ),
    MuscleRegion(
      id: MuscleId.back,
      side: BodySide.back,
      pathBuilder: (Size s) => _polyN(
        s,
        const <Offset>[
          Offset(0.36, 0.22),
          Offset(0.64, 0.22),
          Offset(0.70, 0.44),
          Offset(0.30, 0.44),
        ],
      ),
    ),
    MuscleRegion(
      id: MuscleId.glutes,
      side: BodySide.back,
      pathBuilder: (Size s) => _rectN(
        s,
        const Rect.fromLTWH(0.40, 0.44, 0.20, 0.10),
      ),
    ),
    MuscleRegion(
      id: MuscleId.legs,
      side: BodySide.back,
      pathBuilder: (Size s) => Path.combine(
        PathOperation.union,
        _rectN(s, const Rect.fromLTWH(0.30, 0.54, 0.15, 0.35)),
        _rectN(s, const Rect.fromLTWH(0.54, 0.54, 0.15, 0.35)),
      ),
    ),
  ];
}

