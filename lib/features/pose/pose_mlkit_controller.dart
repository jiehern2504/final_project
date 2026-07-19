import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseMlKitController {
  PoseMlKitController() {
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
  }

  late final PoseDetector _detector;

  Future<List<Pose>> processImage(InputImage inputImage) {
    return _detector.processImage(inputImage);
  }

  Future<void> dispose() => _detector.close();
}
