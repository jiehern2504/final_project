import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

double angleAtPoseLandmarks(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
  final Offset ba = Offset(a.x - b.x, a.y - b.y);
  final Offset bc = Offset(c.x - b.x, c.y - b.y);
  final double dot = ba.dx * bc.dx + ba.dy * bc.dy;
  final double m = ba.distance * bc.distance;
  if (m < 1e-6) return 0;
  final double cos = (dot / m).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}
