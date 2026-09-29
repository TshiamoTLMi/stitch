import 'dart:convert';
import 'dart:io';

import 'package:dls_app/core/constants/wardrobe_taxonomy.dart';
import 'package:dls_app/core/engine/affinity_engine.dart';
import 'package:dls_app/core/engine/candidate_generator.dart';
import 'package:dls_app/models/clothing_item.dart';
import 'package:flutter_test/flutter_test.dart';

ClothingItem _item(
  String id,
  String parent,
  String sub,
  String color,
  List<String> styles,
) {
  final now = DateTime(2026, 1, 1);
  return ClothingItem(
    id: id,
    parentCategory: parent,
    subcategory: sub,
    categoryType: deriveCategoryType(parentCategory: parent, subcategory: sub),
    color: color,
    colorGroup: deriveColorGroup(color),
    styleTags: styles,
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
  late AffinityEngine engine;
  late List<ClothingItem> seedWardrobe;

  setUpAll(() {
    engine =
        AffinityEngine(File('assets/ml_seed_rules.json').readAsStringSync());
    final decoded =
        jsonDecode(File('assets/seed/wardrobe_seed.json').readAsStringSync());
    final items = (decoded['items'] as List).cast<Map<String, dynamic>>();
    seedWardrobe = items
        .map((raw) => ClothingItem.fromMap(raw['id'] as String, raw))
        .toList();
  });

  /// Small hand-built wardrobe where the correct answer is known, used for the
  /// context-sensitivity assertions.
  final curated = <ClothingItem>[
    _item('formal-shirt', 'Tops', 'Button-down shirts', 'white',
        <String>['smart_casual', 'formal']),
    _item('formal-trousers', 'Bottoms', 'Trousers', 'black',
        <String>['formal', 'smart_casual']),
    _item('loafers', 'Footwear', 'Loafers', 'brown',
        <String>['formal', 'smart_casual']),
    _item('casual-tee', 'Tops', 'T-shirts', 'black',
        <String>['casual', 'streetwear']),
    _item('shorts', 'Bottoms', 'Shorts', 'beige', <String>['casual']),
    _item('sneakers', 'Footwear', 'Sneakers', 'white',
        <String>['casual', 'streetwear']),
  ];

  group('seed dataset', () {
    test('loads the 300+ item development wardrobe', () {
      expect(seedWardrobe.length, greaterThanOrEqualTo(300));
    });

    test('every seed item is clean so the whole wardrobe is usable', () {
      expect(seedWardrobe.every((item) => item.status == 'clean'), isTrue);
    });
  });

  group('generation from the 332-item seed dataset', () {
    test('produces ranked candidates', () {
      final ranked = CandidateGenerator(engine: engine).rank(
        wardrobe: seedWardrobe,
        occasion: 'Work',
        weather: 'mild',
        limit: 5,
      );
      expect(ranked, isNotEmpty);
      expect(ranked.length, lessThanOrEqualTo(5));
    });

    test('every candidate passes affinity structural validation', () {
      final ranked = CandidateGenerator(engine: engine).rank(
        wardrobe: seedWardrobe,
        occasion: 'Date',
        weather: 'cold',
        limit: 40,
      );
      expect(ranked, isNotEmpty);
      for (final outfit in ranked) {
        expect(engine.rejectionReason(outfit.items), isNull);
        expect(outfit.breakdown.isValid, isTrue);
        expect(outfit.styleMatchPercent, inInclusiveRange(0, 100));
      }
    });

    test('is sorted by style match descending', () {
      final ranked = CandidateGenerator(engine: engine).rank(
        wardrobe: seedWardrobe,
        occasion: 'Groove',
        weather: 'warm',
        limit: 0,
      );
      expect(ranked.length, greaterThan(1));
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i - 1].styleMatchPercent,
            greaterThanOrEqualTo(ranked[i].styleMatchPercent));
      }
    });

    test('is deterministic across runs', () {
      final generator = CandidateGenerator(engine: engine);
      final a = generator.rank(
          wardrobe: seedWardrobe, occasion: 'Braai', weather: 'hot', limit: 10);
      final b = generator.rank(
          wardrobe: seedWardrobe, occasion: 'Braai', weather: 'hot', limit: 10);
      expect(a.map((o) => o.id).toList(), b.map((o) => o.id).toList());
    });
  });

  group('pruning', () {
    test('caps each slot bucket', () {
      final buckets = CandidateGenerator(engine: engine, bucketCap: 2)
          .partition(seedWardrobe, occasion: 'Work', weather: 'mild');
      for (final entry in buckets.entries) {
        expect(entry.value.length, lessThanOrEqualTo(2));
      }
    });

    test('caps the scored candidate list', () {
      final ranked = CandidateGenerator(
              engine: engine, bucketCap: 4, maxCandidates: 15)
          .rank(wardrobe: seedWardrobe, occasion: 'Work', limit: 0);
      expect(ranked.length, lessThanOrEqualTo(15));
    });

    test('a 332-item wardrobe does not explode combinatorially', () {
      final ranked = CandidateGenerator(engine: engine)
          .rank(wardrobe: seedWardrobe, occasion: 'Work', limit: 0);
      expect(ranked.length, lessThanOrEqualTo(60));
    });
  });

  group('context sensitivity', () {
    test('occasion changes the winning outfit', () {
      final generator = CandidateGenerator(engine: engine, bucketCap: 4);
      final formal = generator.rank(
          wardrobe: curated, occasion: 'Formal event', weather: 'warm', limit: 1);
      final groove = generator.rank(
          wardrobe: curated, occasion: 'Groove', weather: 'warm', limit: 1);
      expect(formal, isNotEmpty);
      expect(groove, isNotEmpty);
      expect(formal.first.id, isNot(groove.first.id));
    });

    test('weather changes the weather component for the same outfit', () {
      final generator = CandidateGenerator(engine: engine, bucketCap: 4);
      const target = 'casual-tee|shorts|sneakers';
      final hot = generator
          .rank(wardrobe: curated, occasion: 'Braai', weather: 'hot', limit: 0)
          .firstWhere((outfit) => outfit.id == target);
      final cold = generator
          .rank(
              wardrobe: curated,
              occasion: 'Braai',
              weather: 'freezing',
              limit: 0)
          .firstWhere((outfit) => outfit.id == target);

      expect(hot.breakdown.weather, greaterThan(cold.breakdown.weather));
      expect(hot.styleMatchPercent, greaterThan(cold.styleMatchPercent));
    });
  });

  group('background isolate ranking', () {
    test('produces the same result as the synchronous path', () async {
      final generator = CandidateGenerator(engine: engine);
      final sync = generator.rank(
          wardrobe: seedWardrobe, occasion: 'Work', weather: 'mild', limit: 5);
      final isolated = await generator.rankAsync(
        rulesJson: engine.sourceJson!,
        weights: engine.defaultWeights,
        wardrobe: seedWardrobe,
        occasion: 'Work',
        weather: 'mild',
        limit: 5,
      );
      expect(isolated, isNotEmpty);
      expect(isolated.map((o) => o.id).toList(), sync.map((o) => o.id).toList());
      expect(isolated.first.styleMatchPercent, sync.first.styleMatchPercent);
    });

    test('round-trips structure, items and components', () async {
      final generator = CandidateGenerator(engine: engine);
      final isolated = await generator.rankAsync(
        rulesJson: engine.sourceJson!,
        weights: engine.defaultWeights,
        wardrobe: seedWardrobe,
        occasion: 'Date',
        weather: 'cold',
        limit: 3,
      );
      expect(isolated, isNotEmpty);
      final top = isolated.first;
      expect(top.structure, isNotNull);
      expect(top.items, isNotEmpty);
      expect(top.styleMatchPercent, inInclusiveRange(0, 100));
      expect(top.breakdown.reasons, isNotEmpty);
      expect(top.contributionKeys, isNotEmpty);
      for (final component in <double>[
        top.breakdown.style,
        top.breakdown.event,
        top.breakdown.weather,
        top.breakdown.color,
        top.breakdown.category,
      ]) {
        expect(component, inInclusiveRange(0.0, 1.0));
      }
    });

    test('applies learned weight overrides passed across the boundary', () async {
      final generator = CandidateGenerator(engine: engine);
      final colourOnly = await generator.rankAsync(
        rulesJson: engine.sourceJson!,
        weights: const <String, double>{
          'w_style': 0.0,
          'w_event': 0.0,
          'w_weather': 0.0,
          'w_color': 1.0,
          'w_category': 0.0,
        },
        wardrobe: seedWardrobe,
        occasion: 'Groove',
        limit: 1,
      );
      expect(colourOnly, isNotEmpty);
      // With all weight on colour, the score must be exactly the colour
      // component - proving the override crossed the isolate boundary.
      final top = colourOnly.first;
      expect(top.styleMatchPercent,
          (top.breakdown.color * 100).round().clamp(0, 100));
    });
  });

  group('weight overrides', () {
    test('applyWeights can be called repeatedly and changes the score', () {
      final engine = AffinityEngine(
        File('assets/ml_seed_rules.json').readAsStringSync(),
      );
      final items = <ClothingItem>[
        _item('t', 'Tops', 'T-shirts', 'red', <String>['casual']),
        _item('b', 'Bottoms', 'Shorts', 'beige', <String>['casual']),
        _item('f', 'Footwear', 'Sneakers', 'white', <String>['casual']),
      ];
      final base = engine.score(items: items, occasion: 'Braai');

      // `applyWeights` merges a complete, normalised vector - exactly what
      // `FeedbackStore` hands over. A second write must not throw
      // (regression: `_weights` used to be `late final`).
      engine.applyWeights(const <String, double>{
        'w_style': 0.0,
        'w_event': 0.0,
        'w_weather': 0.0,
        'w_color': 1.0,
        'w_category': 0.0,
      });
      final colourOnly = engine.score(items: items, occasion: 'Braai');
      expect(colourOnly.styleMatchPercent,
          (colourOnly.color * 100).round().clamp(0, 100));

      engine.applyWeights(const <String, double>{
        'w_style': 1.0,
        'w_event': 0.0,
        'w_weather': 0.0,
        'w_color': 0.0,
        'w_category': 0.0,
      });
      final styleOnly = engine.score(items: items, occasion: 'Braai');
      expect(styleOnly.styleMatchPercent,
          (styleOnly.style * 100).round().clamp(0, 100));
      expect(base.styleMatchPercent, isNot(colourOnly.styleMatchPercent));
    });
  });

  group('all six weather conditions', () {
    const conditions = <String>[
      'hot',
      'warm',
      'mild',
      'cold',
      'freezing',
      'rain',
    ];

    test('each condition maps to its own dropdown label', () {
      final labels = conditions.map(AffinityEngine.weatherLabelFor).toSet();
      expect(labels, hasLength(6));
      expect(
        labels,
        containsAll(<String>['Hot', 'Warm', 'Mild', 'Cold', 'Freezing', 'Rainy']),
      );
    });

    test('an unknown condition falls back to Mild', () {
      expect(AffinityEngine.weatherLabelFor('meteor-shower'), 'Mild');
    });

    test('every condition produces a structurally valid ranking', () {
      final generator = CandidateGenerator(engine: engine, bucketCap: 4);
      for (final condition in conditions) {
        final ranked = generator.rank(
          wardrobe: seedWardrobe,
          occasion: 'Braai',
          weather: condition,
          limit: 1,
        );
        expect(ranked, isNotEmpty, reason: 'no candidate for $condition');
        expect(engine.rejectionReason(ranked.first.items), isNull);
      }
    });

    test('rain lowers a non-waterproof fit compared with mild weather', () {
      final generator = CandidateGenerator(engine: engine, bucketCap: 4);
      const target = 'casual-tee|shorts|sneakers';
      final wet = generator
          .rank(wardrobe: curated, occasion: 'Braai', weather: 'rain', limit: 0)
          .firstWhere((o) => o.id == target);
      final mild = generator
          .rank(wardrobe: curated, occasion: 'Braai', weather: 'mild', limit: 0)
          .firstWhere((o) => o.id == target);
      expect(wet.breakdown.weather, lessThan(mild.breakdown.weather));
    });
  });
}
