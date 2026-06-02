import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Maps [DeviceOrientation] to rotation degrees (Android ML Kit pipeline).
const Map<DeviceOrientation, int> kDeviceOrientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

Uint8List? _planeConcatBuffer;
Uint8List? _nv21WorkBuffer;
int _lastNv21Size = 0;

/// Builds an [InputImage] for ML Kit from a camera frame.
///
/// Android: prefers [ImageFormatGroup.yuv420] (often [InputImageFormat.yuv_420_888]
/// with three planes). Multi-plane frames are converted to NV21 per the
/// [google_ml_kit_flutter](https://github.com/flutter-ml/google_ml_kit_flutter) example.
InputImage? inputImageFromCameraImage({
  required CameraImage image,
  required CameraController controller,
  required CameraDescription camera,
}) {
  final int? rotationCompensation = _rotationCompensation(
    controller: controller,
    camera: camera,
  );
  if (rotationCompensation == null) return null;

  final InputImageRotation? rotation =
      InputImageRotationValue.fromRawValue(rotationCompensation);
  if (rotation == null) return null;

  final InputImageFormat? format =
      InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  if (Platform.isAndroid) {
    const androidSupportedFormats = <InputImageFormat>[
      InputImageFormat.nv21,
      InputImageFormat.yv12,
      InputImageFormat.yuv_420_888,
    ];
    if (!androidSupportedFormats.contains(format)) return null;
  } else if (Platform.isIOS) {
    if (format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;
    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageFormat resolvedFormat = format;
  final Uint8List bytes;
  if (image.planes.length == 1) {
    bytes = image.planes.first.bytes;
  } else if (Platform.isAndroid &&
      (format == InputImageFormat.yuv_420_888 ||
          format == InputImageFormat.yv12) &&
      image.planes.length == 3) {
    bytes = _convertYUV420ToNV21(image);
    resolvedFormat = InputImageFormat.nv21;
  } else {
    bytes = _concatenatePlanes(image);
  }

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: resolvedFormat,
      bytesPerRow: image.planes.first.bytesPerRow,
    ),
  );
}

Uint8List _concatenatePlanes(CameraImage image) {
  final int totalBytes =
      image.planes.fold(0, (int sum, Plane plane) => sum + plane.bytes.length);

  if (_planeConcatBuffer == null || _planeConcatBuffer!.length < totalBytes) {
    _planeConcatBuffer = Uint8List(totalBytes);
  }
  final Uint8List buffer = _planeConcatBuffer!;

  var offset = 0;
  for (final Plane plane in image.planes) {
    final Uint8List bytes = plane.bytes;
    buffer.setRange(offset, offset + bytes.length, bytes);
    offset += bytes.length;
  }

  if (totalBytes == buffer.length) {
    return buffer;
  }
  return Uint8List.sublistView(buffer, 0, totalBytes);
}

Uint8List _convertYUV420ToNV21(CameraImage image) {
  final int width = image.width;
  final int height = image.height;
  final int ySize = width * height;
  final int uvSize = ySize ~/ 2;
  final int requiredSize = ySize + uvSize;

  if (_nv21WorkBuffer == null || _lastNv21Size != requiredSize) {
    _nv21WorkBuffer = Uint8List(requiredSize);
    _lastNv21Size = requiredSize;
  }

  final Uint8List nv21 = _nv21WorkBuffer!;

  final Plane yPlane = image.planes[0];
  int destIndex = 0;
  for (int row = 0; row < height; row++) {
    final int srcRowStart = row * yPlane.bytesPerRow;
    nv21.setRange(destIndex, destIndex + width, yPlane.bytes, srcRowStart);
    destIndex += width;
  }

  final Plane uPlane = image.planes[1];
  final Plane vPlane = image.planes[2];
  final int uvPixelStride = uPlane.bytesPerPixel ?? 1;
  final int vPixelStride = vPlane.bytesPerPixel ?? 1;

  int uvIndex = ySize;
  for (int row = 0; row < height ~/ 2; row++) {
    final int uRowStart = row * uPlane.bytesPerRow;
    final int vRowStart = row * vPlane.bytesPerRow;

    for (int col = 0; col < width ~/ 2; col++) {
      final int uIndex = uRowStart + col * uvPixelStride;
      final int vIndex = vRowStart + col * vPixelStride;

      nv21[uvIndex++] = vPlane.bytes[vIndex];
      nv21[uvIndex++] = uPlane.bytes[uIndex];
    }
  }

  return nv21;
}

int? _rotationCompensation({
  required CameraController controller,
  required CameraDescription camera,
}) {
  final int sensorOrientation = camera.sensorOrientation;
  if (Platform.isIOS) {
    return InputImageRotationValue.fromRawValue(sensorOrientation)?.rawValue;
  }
  if (Platform.isAndroid) {
    int? rotationCompensation =
        kDeviceOrientationDegrees[controller.value.deviceOrientation];
    if (rotationCompensation == null) return null;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    return rotationCompensation;
  }
  return null;
}

/// Same rotation as used in [inputImageFromCameraImage] (for overlay alignment).
InputImageRotation? mlKitRotationForCameraFrame({
  required CameraController controller,
  required CameraDescription camera,
}) {
  final int? deg = _rotationCompensation(
    controller: controller,
    camera: camera,
  );
  if (deg == null) return null;
  return InputImageRotationValue.fromRawValue(deg);
}
