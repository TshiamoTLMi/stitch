import 'package:dls_app/models/clothing_item.dart';
import 'package:dls_app/services/outfit_bot_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = OutfitBotService();

  String categoryTypeFor(String category) {
    final value = category.toLowerCase();
    if (value.contains('shoe') || value.contains('boot') || value.contains('sneaker')) {
      return 'shoes';
    }
    if (value.contains('pant') || value.contains('trouser') || value.contains('jean')) {
      return 'bottom';
    }
    if (value.contains('dress')) {
      return 'full';
    }
    if (value.contains('accessor') || value.contains('belt') || value.contains('hat') || value.contains('bag')) {
      return 'accessory';
    }
    return 'top';
  }

  String parentCategoryFor(String categoryType) {
    switch (categoryType) {
      case 'bottom':
        return 'Bottoms';
      case 'shoes':
        return 'Shoes';
      case 'accessory':
        return 'Accessories';
      case 'full':
        return 'Full Body';
      default:
        return 'Tops';
    }
  }

  ClothingItem item({
    required String id,
    required String category,
    String status = 'clean',
    List<String> tags = const <String>['casual'],
    String? categoryType,
  }) {
    final now = DateTime(2026, 1, 1);
    final resolvedCategoryType = categoryType ?? categoryTypeFor(category);
    return ClothingItem(
      id: id,
      parentCategory: parentCategoryFor(resolvedCategoryType),
      subcategory: category,
      categoryType: resolvedCategoryType,
      color: 'black',
      colorGroup: 'neutral',
      styleTags: tags,
      season: 'All Season',
      status: status,
      gender: 'Unisex',
      imageUrl: 'https://example.com/$id.jpg',
      userId: 'u1',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('returns score 0 and helpful reasoning when no clean items exist', () {
    final result = service.generate(
      wardrobe: <ClothingItem>[
        item(id: '1', category: 'shirt', status: 'dirty'),
      ],
      occasion: 'Work',
      mood: 'Minimal',
      weather: 'Cold',
    );

    expect(result.score, 0);
    expect(result.isValid, isFalse);
    expect(result.reasoning.first, contains('No clean items available'));
  });

  test('builds a valid outfit with clean top bottom and shoes', () {
    final result = service.generate(
      wardrobe: <ClothingItem>[
        item(id: 't1', category: 'shirt', tags: const <String>['smart_casual']),
        item(id: 'b1', category: 'trousers', tags: const <String>['formal']),
        item(id: 's1', category: 'shoes', tags: const <String>['formal']),
      ],
      occasion: 'Work',
      mood: 'Minimal',
      weather: 'Cold',
    );

    expect(result.isValid, isTrue);
    expect(result.shoes, isNotNull);
    expect(result.score, inInclusiveRange(0, 100));
    expect(result.reasoning.join(' '), contains('Top scoring piece'));
  });

  test('normalizes alias categories so generator still succeeds', () {
    final result = service.generate(
      wardrobe: <ClothingItem>[
        item(id: 't1', category: 'tshirt', categoryType: 'unknown'),
        item(id: 'b1', category: 'jeans', categoryType: 'unknown'),
        item(id: 's1', category: 'shoe', categoryType: 'unknown'),
      ],
      occasion: 'Braai',
      mood: 'Street Flex',
      weather: 'Sunny',
    );

    expect(result.top, isNotNull);
    expect(result.bottom, isNotNull);
    expect(result.shoes, isNotNull);
    expect(result.isValid, isTrue);
  });

  test('readiness reports missing shoes clearly', () {
    final readiness = service.checkReadiness(<ClothingItem>[
      item(id: 't1', category: 'shirt', status: 'clean'),
      item(id: 'b1', category: 'trousers', status: 'clean'),
    ]);

    expect(readiness.canGenerate, isFalse);
    expect(readiness.missingRequirements, contains('shoes'));
    expect(readiness.userFriendlyMessage, contains('Add clean'));
  });
}
