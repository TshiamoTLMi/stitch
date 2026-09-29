import 'package:dls_app/models/clothing_item.dart';
import 'package:dls_app/services/outfit_bot_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sprint 9: `OutfitBotService` is now a pre-flight readiness check only.
/// Generation and scoring live in `AffinityEngine` / `CandidateGenerator`.
void main() {
  final service = OutfitBotService();

  ClothingItem item({
    required String id,
    required String parentCategory,
    required String categoryType,
    String status = 'clean',
  }) {
    final now = DateTime(2026, 1, 1);
    return ClothingItem(
      id: id,
      parentCategory: parentCategory,
      subcategory: categoryType,
      categoryType: categoryType,
      color: 'black',
      colorGroup: 'neutral',
      styleTags: const <String>['casual'],
      season: 'All Season',
      status: status,
      gender: 'Unisex',
      imageUrl: '',
      userId: 'u1',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('reports no clean items at all', () {
    final readiness = service.checkReadiness(<ClothingItem>[
      item(id: '1', parentCategory: 'Tops', categoryType: 'top', status: 'in_wash'),
    ]);

    expect(readiness.canGenerate, isFalse);
    expect(readiness.missingRequirements, contains('tops'));
  });

  test('readiness reports missing shoes clearly', () {
    final readiness = service.checkReadiness(<ClothingItem>[
      item(id: 't1', parentCategory: 'Tops', categoryType: 'top'),
      item(id: 'b1', parentCategory: 'Bottoms', categoryType: 'bottom'),
    ]);

    expect(readiness.canGenerate, isFalse);
    expect(readiness.missingRequirements, contains('shoes'));
    expect(readiness.userFriendlyMessage, contains('Add clean'));
  });

  test('a one-piece plus shoes is enough', () {
    final readiness = service.checkReadiness(<ClothingItem>[
      item(id: 'd1', parentCategory: 'Dresses & Jumpsuits', categoryType: 'full'),
      item(id: 's1', parentCategory: 'Footwear', categoryType: 'shoes'),
    ]);

    expect(readiness.canGenerate, isTrue);
  });
}

