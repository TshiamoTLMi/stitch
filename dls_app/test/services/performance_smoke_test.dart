import 'dart:io';

import 'package:dls_app/core/engine/affinity_engine.dart';
import 'package:dls_app/core/engine/candidate_generator.dart';
import 'package:dls_app/models/clothing_item.dart';
import 'package:dls_app/models/event_model.dart';
import 'package:dls_app/services/caption_service.dart';
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

    test('AffinityEngine ranks quickly for a large wardrobe', () {
      final engine =
          AffinityEngine(File('assets/ml_seed_rules.json').readAsStringSync());
      final now = DateTime(2026, 1, 1);
      const parents = <String>[
        'Tops',
        'Bottoms',
        'Footwear',
        'Tops',
        'Bottoms',
        'Footwear',
        'Outerwear',
        'Dresses & Jumpsuits',
      ];
      const subs = <String>[
        'T-shirts',
        'Jeans',
        'Sneakers',
        'Sweaters',
        'Trousers',
        'Loafers',
        'Hoodies',
        'Casual dresses',
      ];
      final wardrobe = List<ClothingItem>.generate(1200, (i) {
        final slot = i % parents.length;
        return ClothingItem(
          id: 'seed-$i',
          parentCategory: parents[slot],
          subcategory: subs[slot],
          categoryType: 'top',
          color: 'black',
          colorGroup: 'neutral',
          styleTags: const <String>['casual'],
          season: 'All Season',
          status: 'clean',
          gender: 'Unisex',
          imageUrl: '',
          userId: 'u1',
          createdAt: now,
          updatedAt: now,
        );
      });

      final sw = Stopwatch()..start();
      final ranked = CandidateGenerator(engine: engine).rank(
        wardrobe: wardrobe,
        occasion: 'Work',
        weather: 'mild',
        limit: 3,
      );
      sw.stop();

      expect(ranked, isNotEmpty);
      expect(ranked.first.styleMatchPercent, inInclusiveRange(0, 100));
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
