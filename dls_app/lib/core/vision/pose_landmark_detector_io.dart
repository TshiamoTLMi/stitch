import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Isolated in its own file so `google_mlkit_pose_detection` (Android/iOS
/// only) is never imported, even transitively, from a web build - only
/// `outfit_pose_scanner.dart` reaches this, and only when `!kIsWeb`.
///
/// Returns a flat, isolate-safe landmark map (`shoulderY`, `hipY`, `ankleY`,
/// `floorY`, `leftX`, `rightX`, all in the original photo's pixel space) or
/// null if no usable pose was found.
Future<Map<String, double>?> detectPoseLandmarks(String filePath) async {
  final detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.single),
  );
  try {
    final input = InputImage.fromFilePath(filePath);
    final poses = await detector.processImage(input);
    if (poses.isEmpty) return null;

    final landmarks = poses.first.landmarks;
    double? yOf(PoseLandmarkType a, PoseLandmarkType b) {
      final la = landmarks[a];
      final lb = landmarks[b];
      if (la == null && lb == null) return null;
      if (la == null) return lb!.y;
      if (lb == null) return la.y;
      return (la.y + lb.y) / 2;
    }

    final shoulderY = yOf(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    final hipY = yOf(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    final ankleY =
        yOf(PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle);
    final floorY = yOf(
      PoseLandmarkType.leftFootIndex,
      PoseLandmarkType.rightFootIndex,
    );

    if (shoulderY == null || hipY == null || ankleY == null) {
      return null;
    }

    final xs = <double>[
      for (final type in const [
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.rightAnkle,
      ])
        if (landmarks[type] != null) landmarks[type]!.x,
    ];
    if (xs.length < 4) return null;

    return <String, double>{
      'shoulderY': shoulderY,
      'hipY': hipY,
      'ankleY': ankleY,
      if (floorY != null) 'floorY': floorY,
      'leftX': xs.reduce((a, b) => a < b ? a : b),
      'rightX': xs.reduce((a, b) => a > b ? a : b),
    };
  } finally {
    await detector.close();
  }
}
