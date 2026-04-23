import 'package:dls_app/models/clothing_item.dart';
import 'package:dls_app/models/event_model.dart';
import 'package:dls_app/services/caption_service.dart';
import 'package:dls_app/services/outfit_bot_service.dart';
import 'package:dls_app/services/recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Performance smoke tests', () {
    ClothingItem item(int i) {
      final now = DateTime(2026, 1, 1);
      final categoryCycle = <String>['shirt', 'pants', 'shoes', 'accessory'];
      final category = categoryCycle[i % categoryCycle.length];
      final categoryType = switch (category) {
        'shirt' => 'top',
        'pants' => 'bottom',
        'shoes' => 'shoes',
        _ => 'accessory',
      };

      return ClothingItem(
        id: 'item_$i',
        parentCategory: 'Test',
        subcategory: category,
        categoryType: categoryType,
        color: 'black',
        colorGroup: 'neutral',
        styleTags: const <String>['casual', 'smart_casual'],
        season: 'All Season',
        status: 'clean',
        gender: 'Unisex',
        imageUrl: 'https://example.com/$i.jpg',
        userId: 'u1',
        createdAt: now,
        updatedAt: now,
      );
    }

    EventModel event(int i) {
      return EventModel(
        id: 'e_$i',
        userId: 'u1',
        name: 'Event $i',
        date: DateTime(2026, 2, 1),
        occasion: i.isEven ? 'Work' : 'Event',
      );
    }

    test('OutfitBot generates quickly for large wardrobe', () {
      final service = OutfitBotService();
      final wardrobe = List<ClothingItem>.generate(1200, item);

      final sw = Stopwatch()..start();
      final result = service.generate(
        wardrobe: wardrobe,
        occasion: 'Work',
        mood: 'Minimal',
        weather: 'Cold',
      );
      sw.stop();

      expect(result.score, inInclusiveRange(0, 100));
      expect(sw.elapsedMilliseconds, lessThan(650));
    });

    test('RecommendationService computes suggestions quickly', () {
      final service = RecommendationService();
      final wardrobe = List<ClothingItem>.generate(900, item);
      final events = List<EventModel>.generate(300, event);

      final sw = Stopwatch()..start();
      final suggestions = service.buildMissingItems(
        wardrobe: wardrobe,
        upcomingEvents: events,
      );
      sw.stop();

      expect(suggestions, isNotNull);
      expect(sw.elapsedMilliseconds, lessThan(350));
    });

    test('CaptionService generates captions quickly in batch', () {
      final service = CaptionService();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 1200; i++) {
        final caption = service.generate(
          occasion: i.isEven ? 'Work' : 'Braai',
          mood: i % 3 == 0 ? 'Minimal' : 'Street Flex',
          weather: i % 5 == 0 ? 'Rainy' : 'Sunny',
        );
        expect(caption, isNotEmpty);
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(450));
    });
  });
}
