import 'dart:typed_data';

import 'package:dls_app/models/clothing_item.dart';
import 'package:dls_app/models/outfit_result.dart';
import 'package:dls_app/services/outfit_image_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  ClothingItem item(String id, String categoryType, String subcategory) {
    final now = DateTime(2026, 1, 1);
    return ClothingItem(
      id: id,
      parentCategory: 'Test',
      subcategory: subcategory,
      categoryType: categoryType,
      color: 'black',
      colorGroup: 'neutral',
      styleTags: const <String>['casual'],
      season: 'All Season',
      status: 'clean',
      gender: 'Unisex',
      imageUrl: 'assets/seed/images/test-$id.jpg',
      localImagePath: 'assets/seed/images/test-$id.jpg',
      userId: 'u1',
      createdAt: now,
      updatedAt: now,
    );
  }

  OutfitResult validResult() {
    return OutfitResult(
      top: item('top', 'top', 'shirt'),
      bottom: item('bottom', 'bottom', 'trousers'),
      shoes: item('shoes', 'shoes', 'sneakers'),
      accessory: item('accessory', 'accessory', 'watch'),
      score: 82,
      reasoning: const <String>['test'],
    );
  }

  /// Local-first: the service resolves bundled assets and never performs HTTP.
  test('composeOutfitImage returns non-empty png bytes from local assets',
      () async {
    final sample = img.Image(width: 180, height: 180);
    img.fill(sample, color: img.ColorRgb8(30, 30, 30));
    img.fillRect(sample,
        x1: 40, y1: 30, x2: 140, y2: 150, color: img.ColorRgb8(220, 120, 80));
    final png = Uint8List.fromList(img.encodePng(sample));

    var assetReads = 0;
    final service = OutfitImageService(
      assetLoader: (assetPath) async {
        expect(assetPath.startsWith('assets/'), isTrue);
        assetReads++;
        return png;
      },
    );

    final bytes = await service.composeOutfitImage(
      result: validResult(),
      title: 'Test Fit',
      cleanupBackground: true,
    );

    expect(bytes.isNotEmpty, isTrue);
    expect(assetReads, greaterThan(0));
  });

  test('composeOutfitImage renders with no local images available', () async {
    final service = OutfitImageService(assetLoader: (_) async => null);
    final bytes = await service.composeOutfitImage(
      result: validResult(),
      title: 'Empty',
    );
    expect(bytes.isNotEmpty, isTrue);
  });
}
