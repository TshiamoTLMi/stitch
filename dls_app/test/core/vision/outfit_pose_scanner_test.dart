import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dls_app/core/vision/outfit_pose_scanner.dart';

/// Builds a synthetic "full-body photo" with three solid-colour bands at
/// the same fractional heights [OutfitPoseScanner]'s fixed fallback bands
/// use (top 0-50%, middle 50-88%, bottom 88-100%), so scanning it with no
/// [filePath] (forcing the fallback path, since pose detection never runs
/// without a file path) exercises real bounding-box math end-to-end.
Uint8List _syntheticOutfitPhoto() {
  const width = 300;
  const height = 1000;
  final image = img.Image(width: width, height: height);

  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: width - 1,
    y2: 499,
    color: img.ColorRgb8(200, 30, 30), // matches the 'red' taxonomy colour
  );
  img.fillRect(
    image,
    x1: 0,
    y1: 500,
    x2: width - 1,
    y2: 879,
    color: img.ColorRgb8(40, 90, 200), // matches 'blue'
  );
  img.fillRect(
    image,
    x1: 0,
    y1: 880,
    x2: width - 1,
    y2: height - 1,
    color: img.ColorRgb8(20, 20, 20), // matches 'black'
  );

  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

void main() {
  group('OutfitPoseScanner.scan (fallback bands, no filePath)', () {
    test('slices a photo into top/bottom/footwear crops', () async {
      final outcome = await OutfitPoseScanner.scan(_syntheticOutfitPhoto());

      expect(outcome.usedFallbackBands, isTrue);
      expect(outcome.garments, hasLength(3));
      expect(outcome.garments.map((g) => g.slot), [
        OutfitSlot.top,
        OutfitSlot.bottom,
        OutfitSlot.footwear,
      ]);
    });

    test('each crop decodes as a valid image under the size cap', () async {
      final outcome = await OutfitPoseScanner.scan(_syntheticOutfitPhoto());

      for (final garment in outcome.garments) {
        expect(garment.imageBytes.length, lessThanOrEqualTo(300 * 1024));
        final decoded = img.decodeImage(garment.imageBytes);
        expect(decoded, isNotNull);
      }
    });

    test('maps each band\'s dominant colour through the existing taxonomy', () async {
      final outcome = await OutfitPoseScanner.scan(_syntheticOutfitPhoto());
      final byLabel = {for (final g in outcome.garments) g.label: g};

      expect(byLabel['Top']!.color, 'red');
      expect(byLabel['Top']!.colorGroup, 'warm');
      expect(byLabel['Bottom']!.color, 'blue');
      expect(byLabel['Bottom']!.colorGroup, 'cool');
      expect(byLabel['Shoes']!.color, 'black');
      expect(byLabel['Shoes']!.colorGroup, 'neutral');
    });

    test('defaults each slot to a sensible category/subcategory', () async {
      final outcome = await OutfitPoseScanner.scan(_syntheticOutfitPhoto());
      final byLabel = {for (final g in outcome.garments) g.label: g};

      expect(byLabel['Top']!.parentCategory, 'Tops');
      expect(byLabel['Bottom']!.parentCategory, 'Bottoms');
      expect(byLabel['Shoes']!.parentCategory, 'Footwear');
    });

    test('returns no garments for an undecodable photo', () async {
      final outcome =
          await OutfitPoseScanner.scan(Uint8List.fromList([1, 2, 3]));
      expect(outcome.garments, isEmpty);
    });
  });
}
