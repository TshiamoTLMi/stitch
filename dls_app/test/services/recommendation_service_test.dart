import 'package:dls_app/models/clothing_item.dart';
import 'package:dls_app/models/event_model.dart';
import 'package:dls_app/services/recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = RecommendationService();

  ClothingItem item({required String id, required String category}) {
    final now = DateTime(2026, 1, 1);
    return ClothingItem(
      id: id,
      category: category,
      color: 'black',
      styleTags: const <String>['casual'],
      status: 'clean',
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

    expect(suggestions, orderedEquals(<String>['Belt', 'Blazer', 'Formal shoes']));
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
}
