/// Web build of [detectPoseLandmarks]. `google_mlkit_pose_detection`
/// transitively imports `dart:io`, which does not exist on web, so this stub
/// (selected by the `dart.library.io` conditional import in
/// `outfit_pose_scanner.dart`) is compiled in its place - the real plugin is
/// never part of a web build's dependency graph.
///
/// Web always falls back to [OutfitPoseScanner]'s fixed fractional bands.
Future<Map<String, double>?> detectPoseLandmarks(String filePath) async =>
    null;
