import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../constants/wardrobe_taxonomy.dart';
import 'pose_landmark_detector_stub.dart'
    if (dart.library.io) 'pose_landmark_detector_io.dart' as pose;

/// Which garment a cropped region of a full-body photo represents.
enum OutfitSlot { top, bottom, footwear }

/// A single garment auto-extracted from a full-body outfit photo, ready for
/// review before it is saved to the closet.
class ScannedGarment {
  const ScannedGarment({
    required this.slot,
    required this.imageBytes,
    required this.parentCategory,
    required this.subcategory,
    required this.color,
    required this.colorGroup,
  });

  final OutfitSlot slot;
  final Uint8List imageBytes;
  final String parentCategory;
  final String subcategory;
  final String color;
  final String colorGroup;

  String get label => switch (slot) {
        OutfitSlot.top => 'Top',
        OutfitSlot.bottom => 'Bottom',
        OutfitSlot.footwear => 'Shoes',
      };
}

/// Result of one [OutfitPoseScanner.scan] call.
class ScanOutcome {
  const ScanOutcome({required this.garments, required this.usedFallbackBands});

  final List<ScannedGarment> garments;

  /// True when fixed fractional bands were used instead of real pose
  /// landmarks (always true on web; also true on mobile when no usable pose
  /// was found in the photo). Callers should label these crops approximate.
  final bool usedFallbackBands;
}

/// Slices a full-body outfit photo into Top / Bottom / Footwear crops.
///
/// On Android/iOS this uses on-device pose landmarks (via
/// `google_mlkit_pose_detection`, which never leaves the device and is free)
/// to find the shoulder/hip/ankle bands. On Flutter Web (where that plugin
/// is unavailable) and whenever pose detection fails to find a usable pose,
/// it falls back to fixed fractional bands of the photo - an approximate
/// crop the review screen should label as such.
///
/// [QA TEST POINT] Full-body scan
/// - A clear, front-facing full-body photo yields 3 sensible crops.
/// - A web build never attempts to load the pose-detection plugin.
/// - Each crop is under 300 KB and still loads as a valid JPEG.
class OutfitPoseScanner {
  const OutfitPoseScanner._();

  /// Target soft cap for each cropped/compressed garment image.
  static const int maxCropBytes = 300 * 1024;

  /// Runs the full slice pipeline for one photo.
  ///
  /// [filePath] should be the on-disk path of the photo (unavailable and
  /// unnecessary on web, where landmark detection is always skipped).
  static Future<ScanOutcome> scan(
    Uint8List photoBytes, {
    String? filePath,
  }) async {
    final landmarks =
        filePath != null ? await _detectLandmarks(filePath) : null;

    final job = _SliceJob(photoBytes: photoBytes, landmarks: landmarks);
    final result = await compute(_sliceAndAnalyze, job);

    final garments = <ScannedGarment>[];
    if (result.top != null) {
      garments.add(_toGarment(OutfitSlot.top, result.top!));
    }
    if (result.bottom != null) {
      garments.add(_toGarment(OutfitSlot.bottom, result.bottom!));
    }
    if (result.footwear != null) {
      garments.add(_toGarment(OutfitSlot.footwear, result.footwear!));
    }
    return ScanOutcome(garments: garments, usedFallbackBands: landmarks == null);
  }

  static ScannedGarment _toGarment(OutfitSlot slot, _CropOut crop) {
    final colorName = _nearestColorName(crop.r, crop.g, crop.b);
    final (parentCategory, subcategory) = switch (slot) {
      OutfitSlot.top => ('Tops', categoryTaxonomy['Tops']!.first),
      OutfitSlot.bottom => ('Bottoms', categoryTaxonomy['Bottoms']!.first),
      OutfitSlot.footwear => ('Footwear', categoryTaxonomy['Footwear']!.first),
    };
    return ScannedGarment(
      slot: slot,
      imageBytes: crop.bytes,
      parentCategory: parentCategory,
      subcategory: subcategory,
      color: colorName,
      colorGroup: deriveColorGroup(colorName),
    );
  }

  /// Runs on-device pose detection and reduces the result to the flat,
  /// isolate-safe landmark map [_sliceAndAnalyze] expects. Returns null if
  /// no usable pose was found (caller falls back to fixed bands). On web
  /// this resolves to the stub implementation, which always returns null.
  static Future<Map<String, double>?> _detectLandmarks(String path) async {
    try {
      return await pose.detectPoseLandmarks(path);
    } catch (_) {
      return null;
    }
  }
}

// ── Isolate-safe slicing ─────────────────────────────────────────────────

class _SliceJob {
  const _SliceJob({required this.photoBytes, required this.landmarks});
  final Uint8List photoBytes;
  final Map<String, double>? landmarks;
}

class _CropOut {
  const _CropOut({
    required this.bytes,
    required this.r,
    required this.g,
    required this.b,
  });
  final Uint8List bytes;
  final int r;
  final int g;
  final int b;
}

class _SliceResult {
  const _SliceResult({this.top, this.bottom, this.footwear});
  final _CropOut? top;
  final _CropOut? bottom;
  final _CropOut? footwear;
}

/// Top-level so it can run via [compute] in a background isolate.
_SliceResult _sliceAndAnalyze(_SliceJob job) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(job.photoBytes);
  } catch (_) {
    // Some malformed input can make package:image's format sniffer throw
    // (e.g. a short byte sequence that looks like a truncated PSD header)
    // rather than return null - treat that the same as "undecodable".
    decoded = null;
  }
  if (decoded == null) {
    return const _SliceResult();
  }

  final w = decoded.width.toDouble();
  final h = decoded.height.toDouble();
  final lm = job.landmarks;

  double shoulderY, hipY, ankleY, floorY, leftX, rightX;
  if (lm != null &&
      lm.containsKey('shoulderY') &&
      lm.containsKey('hipY') &&
      lm.containsKey('ankleY') &&
      lm.containsKey('leftX') &&
      lm.containsKey('rightX')) {
    shoulderY = lm['shoulderY']!;
    hipY = lm['hipY']!;
    ankleY = lm['ankleY']!;
    floorY = lm['floorY'] ?? (ankleY + (ankleY - hipY) * 0.15);
    leftX = lm['leftX']!;
    rightX = lm['rightX']!;
  } else {
    // Fixed fractional bands: used on web, or when pose detection fails.
    shoulderY = h * 0.12;
    hipY = h * 0.50;
    ankleY = h * 0.88;
    floorY = h;
    leftX = w * 0.10;
    rightX = w * 0.90;
  }

  final padX = (rightX - leftX).abs() * 0.15;
  final bandLeft = (leftX - padX).clamp(0, w).toDouble();
  final bandRight = (rightX + padX).clamp(0, w).toDouble();

  final topCrop = _cropBand(
    decoded,
    bandLeft,
    bandRight,
    shoulderY - (hipY - shoulderY) * 0.15,
    hipY,
    w,
    h,
  );
  final bottomCrop = _cropBand(
    decoded,
    bandLeft,
    bandRight,
    hipY,
    ankleY + (ankleY - hipY) * 0.05,
    w,
    h,
  );
  final footwearCrop = _cropBand(
    decoded,
    bandLeft,
    bandRight,
    ankleY,
    floorY,
    w,
    h,
  );

  return _SliceResult(top: topCrop, bottom: bottomCrop, footwear: footwearCrop);
}

_CropOut? _cropBand(
  img.Image src,
  double left,
  double right,
  double top,
  double bottom,
  double w,
  double h,
) {
  final l = left.clamp(0, w - 1).toInt();
  final r = right.clamp(l + 1, w).toInt();
  final t = top.clamp(0, h - 1).toInt();
  final b = bottom.clamp(t + 1, h).toInt();
  if (r <= l || b <= t) return null;

  final cropped = img.copyCrop(src, x: l, y: t, width: r - l, height: b - t);
  final (red, green, blue) = _averageCenterColor(cropped);
  final bytes = _compressUnderLimit(cropped);
  if (bytes == null) return null;

  return _CropOut(bytes: bytes, r: red, g: green, b: blue);
}

/// Samples a center region of [image], ignoring the outer ~20% border where
/// background tends to bleed in, and returns its average RGB.
(int, int, int) _averageCenterColor(img.Image image) {
  final marginX = (image.width * 0.2).round();
  final marginY = (image.height * 0.2).round();
  final x0 = marginX;
  final x1 = image.width - marginX;
  final y0 = marginY;
  final y1 = image.height - marginY;
  if (x1 <= x0 || y1 <= y0) return (128, 128, 128);

  final stepX = ((x1 - x0) / 24).clamp(1, double.infinity).round();
  final stepY = ((y1 - y0) / 24).clamp(1, double.infinity).round();

  var rSum = 0, gSum = 0, bSum = 0, count = 0;
  for (var y = y0; y < y1; y += stepY) {
    for (var x = x0; x < x1; x += stepX) {
      final pixel = image.getPixel(x, y);
      rSum += pixel.r.toInt();
      gSum += pixel.g.toInt();
      bSum += pixel.b.toInt();
      count++;
    }
  }
  if (count == 0) return (128, 128, 128);
  return (rSum ~/ count, gSum ~/ count, bSum ~/ count);
}

Uint8List? _compressUnderLimit(img.Image image) {
  var quality = 80;
  Uint8List? last;
  while (quality >= 30) {
    final bytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    last = bytes;
    if (bytes.length <= OutfitPoseScanner.maxCropBytes) return bytes;
    quality -= 10;
  }
  return last;
}

/// Nearest-neighbour match of a sampled RGB against the app's existing named
/// colour taxonomy ([colorGroupMembership] in `wardrobe_taxonomy.dart`), so
/// scanned garments resolve through the same [deriveColorGroup] every other
/// upload path uses - no parallel colour system.
const Map<String, (int, int, int)> _namedColorRgb = <String, (int, int, int)>{
  'black': (20, 20, 20),
  'white': (245, 245, 245),
  'grey': (128, 128, 128),
  'gray': (128, 128, 128),
  'navy': (20, 30, 70),
  'beige': (222, 202, 168),
  'tan': (210, 180, 140),
  'brown': (101, 67, 33),
  'cream': (245, 235, 210),
  'red': (200, 30, 30),
  'pink': (230, 150, 180),
  'yellow': (230, 200, 40),
  'orange': (230, 120, 30),
  'blue': (40, 90, 200),
  'green': (50, 140, 70),
  'teal': (30, 140, 140),
  'purple': (120, 60, 160),
  'olive': (110, 110, 50),
};

String _nearestColorName(int r, int g, int b) {
  var best = 'black';
  var bestDist = double.infinity;
  for (final entry in _namedColorRgb.entries) {
    final (nr, ng, nb) = entry.value;
    final dr = r - nr;
    final dg = g - ng;
    final db = b - nb;
    final dist = (dr * dr + dg * dg + db * db).toDouble();
    if (dist < bestDist) {
      bestDist = dist;
      best = entry.key;
    }
  }
  return best;
}
