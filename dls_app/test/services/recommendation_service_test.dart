import 'package:dls_app/models/clothing_item.dart';
import 'package:dls_app/models/event_model.dart';
import 'package:dls_app/models/missing_item_recommendation.dart';
import 'package:dls_app/services/recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = RecommendationService();

  String categoryTypeFor(String category) {
    final value = category.toLowerCase();
    if (value.contains('shoe') || value.contains('boot') || value.contains('sneaker')) {
      return 'shoes';
    }
    if (value.contains('pant') || value.contains('trouser') || value.contains('jean')) {
      return 'bottom';
    }
    if (value.contains('accessor') || value.contains('belt') || value.contains('hat') || value.contains('bag')) {
      return 'accessory';
    }
    if (value.contains('dress')) {
      return 'full';
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

  ClothingItem item({required String id, required String category}) {
    final now = DateTime(2026, 1, 1);
    final categoryType = categoryTypeFor(category);
    return ClothingItem(
      id: id,
      parentCategory: parentCategoryFor(categoryType),
      subcategory: category,
      categoryType: categoryType,
      color: 'black',
      colorGroup: 'neutral',
      styleTags: const <String>['casual'],
      season: 'All Season',
      status: 'clean',
      gender: 'Unisex',
      imageUrl: 'https://example.com/$id.jpg',
      userId: 'u1',
      createdAt: now,
      updatedAt: now,
    );
  }

  EventModel event({required String id, required String occasion}) {
    return EventModel(
      id: id,
      userId: 'u1',
      name: 'Event $id',
      date: DateTime(2026, 1, 2),
      occasion: occasion,
    );
  }

  test('returns sorted and deduplicated missing item suggestions', () {
    final suggestions = service.buildMissingItems(
      wardrobe: <ClothingItem>[
        item(id: '1', category: 'shirt'),
      ],
      upcomingEvents: <EventModel>[
        event(id: 'e1', occasion: 'Work'),
        event(id: 'e2', occasion: 'Event'),
      ],
    );

    expect(suggestions, orderedEquals(<String>['Belt', 'Formal shoes']));
  });

  test('returns empty list when wardrobe already covers event needs', () {
    final suggestions = service.buildMissingItems(
      wardrobe: <ClothingItem>[
        item(id: '1', category: 'shirt'),
        item(id: '2', category: 'shoes'),
        item(id: '3', category: 'accessories'),
        item(id: '4', category: 'jacket'),
      ],
      upcomingEvents: <EventModel>[
        event(id: 'e1', occasion: 'Work'),
        event(id: 'e2', occasion: 'Formal Event'),
      ],
    );

    expect(suggestions, isEmpty);
  });

  test('returns structured reason, state, action, and deterministic dedupe key', () {
    final recommendations = service.buildRecommendations(
      wardrobe: <ClothingItem>[item(id: '1', category: 'shirt')],
      upcomingEvents: <EventModel>[
        event(id: 'e1', occasion: 'Work'),
        event(id: 'e2', occasion: 'Work'),
      ],
    );

    expect(recommendations, isNotEmpty);
    expect(recommendations.first.reason, contains('Work'));
    expect(recommendations.first.state, RecommendationState.missing);
    expect(recommendations.first.action, RecommendationAction.addToWardrobe);
    expect(recommendations.map((item) => item.dedupeKey).toSet().length, recommendations.length);
  });
}
