import 'dart:convert';
import 'dart:io';

import 'package:dls_app/core/constants/wardrobe_taxonomy.dart';
import 'package:dls_app/core/engine/affinity_engine.dart';
import 'package:dls_app/core/engine/candidate_generator.dart';
import 'package:dls_app/core/engine/outfit_theme.dart';
import 'package:dls_app/models/clothing_item.dart';
import 'package:flutter_test/flutter_test.dart';

ClothingItem _item(String id, String parent, String sub, String color) {
  final now = DateTime(2026, 1, 1);
  return ClothingItem(
    id: id,
    parentCategory: parent,
    subcategory: sub,
    categoryType: deriveCategoryType(parentCategory: parent, subcategory: sub),
    color: color,
    colorGroup: deriveColorGroup(color),
    styleTags: const <String>['casual'],
    season: 'All Season',
    status: 'clean',
    gender: 'Unisex',
    imageUrl: '',
    userId: 'u1',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('OutfitTheme palette filter', () {
    test('none accepts every item, including ones without a colour', () {
      expect(OutfitTheme.none.isActive, isFalse);
      expect(OutfitTheme.none.accepts(_item('a', 'Tops', 'T-shirts', 'red')),
          isTrue);
      expect(OutfitTheme.none.accepts(_item('b', 'Tops', 'T-shirts', '')),
          isTrue);
    });

    test('all-white party accepts white and cream, rejects black', () {
      const theme = OutfitTheme.allWhite;
      expect(theme.accepts(_item('a', 'Tops', 'T-shirts', 'white')), isTrue);
      expect(theme.accepts(_item('b', 'Tops', 'T-shirts', 'cream')), isTrue);
      expect(theme.accepts(_item('c', 'Tops', 'T-shirts', 'Off-white')), isTrue);
      expect(theme.accepts(_item('d', 'Tops', 'T-shirts', 'black')), isFalse);
      expect(theme.accepts(_item('e', 'Tops', 'T-shirts', 'navy')), isFalse);
    });

    test('black and white party accepts black, white and grey only', () {
      const theme = OutfitTheme.blackAndWhite;
      expect(theme.accepts(_item('a', 'Tops', 'T-shirts', 'black')), isTrue);
      expect(theme.accepts(_item('b', 'Tops', 'T-shirts', 'white')), isTrue);
      expect(theme.accepts(_item('c', 'Tops', 'T-shirts', 'grey')), isTrue);
      expect(theme.accepts(_item('d', 'Tops', 'T-shirts', 'Charcoal grey')),
          isTrue);
      expect(theme.accepts(_item('e', 'Tops', 'T-shirts', 'red')), isFalse);
    });

    test('an active theme rejects items with no colour set', () {
      expect(
        OutfitTheme.allWhite.accepts(_item('a', 'Tops', 'T-shirts', '')),
        isFalse,
      );
    });

    test('fromName falls back to none for unknown input', () {
      expect(OutfitTheme.fromName('allWhite'), OutfitTheme.allWhite);
      expect(OutfitTheme.fromName('blackAndWhite'), OutfitTheme.blackAndWhite);
      expect(OutfitTheme.fromName('unknown'), OutfitTheme.none);
      expect(OutfitTheme.fromName(null), OutfitTheme.none);
    });
  });

  group('alternate weather mapping', () {
    test('a dry forecast offers rain as the backup', () {
      expect(AffinityEngine.alternateWeatherFor('Hot'), 'rain');
      expect(AffinityEngine.alternateWeatherFor('Warm'), 'rain');
      expect(AffinityEngine.alternateWeatherFor('Cold'), 'rain');
    });

    test('a rainy forecast offers a dry mild fit as the backup', () {
      expect(AffinityEngine.alternateWeatherFor('Rainy'), 'mild');
      expect(AffinityEngine.alternateWeatherFor('rain'), 'mild');
    });

    test('a missing forecast still produces a backup', () {
      expect(AffinityEngine.alternateWeatherFor(null), 'rain');
    });
  });

  group('recommend', () {
    late AffinityEngine engine;
    late List<ClothingItem> seedWardrobe;

    setUpAll(() {
      engine =
          AffinityEngine(File('assets/ml_seed_rules.json').readAsStringSync());
      final decoded = jsonDecode(
          File('assets/seed/wardrobe_seed.json').readAsStringSync());
      final items = (decoded['items'] as List).cast<Map<String, dynamic>>();
      seedWardrobe = items
          .map((raw) => ClothingItem.fromMap(raw['id'] as String, raw))
          .toList();
    });

    test('returns a dry-weather primary and a rain backup on the seed', () {
      final rec = CandidateGenerator(engine: engine).recommend(
        wardrobe: seedWardrobe,
        occasion: 'Braai',
        weather: 'Hot',
      );
      expect(rec.primary, isNotNull);
      expect(rec.alternate, isNotNull);
      expect(rec.alternateWeather, 'rain');
      expect(rec.alternate!.id, isNot(rec.primary!.id));
    });

    test('the backup is never the same outfit as the primary', () {
      final rec = CandidateGenerator(engine: engine).recommend(
        wardrobe: seedWardrobe,
        occasion: 'Work',
        weather: 'Rainy',
      );
      expect(rec.primary, isNotNull);
      expect(rec.alternateWeather, 'mild');
      if (rec.alternate != null) {
        expect(rec.alternate!.id, isNot(rec.primary!.id));
      }
    });

    test('every item in a themed recommendation sits in the palette', () {
      final rec = CandidateGenerator(engine: engine).recommend(
        wardrobe: seedWardrobe,
        occasion: 'Event',
        weather: 'Warm',
        theme: OutfitTheme.allWhite,
      );
      for (final outfit in <ScoredOutfit?>[rec.primary, rec.alternate]) {
        if (outfit == null) continue;
        for (final item in outfit.items) {
          expect(OutfitTheme.allWhite.accepts(item), isTrue,
              reason: '${item.id} (${item.color}) is outside the palette');
        }
      }
    });

    test('an impossible theme returns no primary instead of a bad outfit', () {
      // Only black pieces exist, so an all-white party has nothing to wear.
      final blackOnly = <ClothingItem>[
        _item('t1', 'Tops', 'T-shirts', 'black'),
        _item('b1', 'Bottoms', 'Trousers', 'black'),
        _item('s1', 'Footwear', 'Sneakers', 'black'),
      ];
      final rec = CandidateGenerator(engine: engine).recommend(
        wardrobe: blackOnly,
        occasion: 'Event',
        weather: 'Warm',
        theme: OutfitTheme.allWhite,
      );
      expect(rec.primary, isNull);
      expect(rec.alternate, isNull);
      expect(rec.alternateWeather, isNull);
    });
  });
}
