import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'pose_coordinate_translator.dart';

/// Skeleton overlay; uses ML Kit coordinate translation so lines match the preview.
class PosePainter extends CustomPainter {
  PosePainter({
    required this.imageSize,
    required this.poses,
    required this.rotation,
    required this.lensDirection,
  });

  final Size imageSize;
  final List<Pose> poses;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;

  Offset _map(PoseLandmark l, Size canvas) {
    return translateLandmark(l, canvas, imageSize, rotation, lensDirection);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return;

    final Paint jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.greenAccent;

    final Paint leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.yellowAccent;

    final Paint rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.lightBlueAccent;

    for (final Pose pose in poses) {
      for (final PoseLandmark landmark in pose.landmarks.values) {
        canvas.drawCircle(_map(landmark, size), 3, jointPaint);
      }

      void paintLine(
        PoseLandmarkType type1,
        PoseLandmarkType type2,
        Paint paintType,
      ) {
        final PoseLandmark? j1 = pose.landmarks[type1];
        final PoseLandmark? j2 = pose.landmarks[type2];
        if (j1 == null || j2 == null) return;
        canvas.drawLine(_map(j1, size), _map(j2, size), paintType);
      }

      paintLine(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        leftPaint,
      );
      paintLine(
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
        leftPaint,
      );
      paintLine(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
        rightPaint,
      );
      paintLine(
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
        rightPaint,
      );

      paintLine(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip,
        leftPaint,
      );
      paintLine(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip,
        rightPaint,
      );

      paintLine(
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        leftPaint,
      );
      paintLine(
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
        leftPaint,
      );
      paintLine(
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        rightPaint,
      );
      paintLine(
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
        rightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.poses != poses ||
        oldDelegate.rotation != rotation ||
        oldDelegate.lensDirection != lensDirection;
  }
}
