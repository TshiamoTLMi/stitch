import 'dart:io';

import 'package:dls_app/core/constants/wardrobe_taxonomy.dart';
import 'package:dls_app/core/engine/affinity_engine.dart';
import 'package:dls_app/models/clothing_item.dart';
import 'package:flutter_test/flutter_test.dart';

ClothingItem item({
  required String id,
  required String parent,
  required String sub,
  required String color,
  List<String> styles = const <String>['casual'],
}) {
  final now = DateTime(2026, 1, 1);
  return ClothingItem(
    id: id,
    parentCategory: parent,
    subcategory: sub,
    categoryType: deriveCategoryType(
      parentCategory: parent,
      subcategory: sub,
    ),
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

ClothingItem get shirt => item(
      id: 'shirt',
      parent: 'Tops',
      sub: 'Button-down shirts',
      color: 'white',
      styles: const <String>['smart_casual', 'formal'],
    );
ClothingItem get tee => item(
      id: 'tee',
      parent: 'Tops',
      sub: 'T-shirts',
      color: 'black',
      styles: const <String>['casual', 'streetwear'],
    );
ClothingItem get sweater => item(
      id: 'sweater',
      parent: 'Tops',
      sub: 'Sweaters',
      color: 'beige',
      styles: const <String>['casual', 'smart_casual'],
    );
ClothingItem get jeans => item(
      id: 'jeans',
      parent: 'Bottoms',
      sub: 'Jeans',
      color: 'blue',
      styles: const <String>['casual', 'streetwear'],
    );
ClothingItem get trousers => item(
      id: 'trousers',
      parent: 'Bottoms',
      sub: 'Trousers',
      color: 'black',
      styles: const <String>['formal', 'smart_casual'],
    );
ClothingItem get shorts => item(
      id: 'shorts',
      parent: 'Bottoms',
      sub: 'Shorts',
      color: 'beige',
      styles: const <String>['casual'],
    );
ClothingItem get blazer => item(
      id: 'blazer',
      parent: 'Outerwear',
      sub: 'Blazers',
      color: 'black',
      styles: const <String>['formal', 'smart_casual'],
    );
ClothingItem get hoodie => item(
      id: 'hoodie',
      parent: 'Outerwear',
      sub: 'Hoodies',
      color: 'grey',
      styles: const <String>['streetwear', 'casual'],
    );
ClothingItem get coat => item(
      id: 'coat',
      parent: 'Outerwear',
      sub: 'Puffer jackets',
      color: 'navy',
      styles: const <String>['casual', 'sportswear'],
    );
ClothingItem get dress => item(
      id: 'dress',
      parent: 'Dresses & Jumpsuits',
      sub: 'Evening dresses',
      color: 'black',
      styles: const <String>['formal'],
    );
ClothingItem get casualDress => item(
      id: 'casual-dress',
      parent: 'Dresses & Jumpsuits',
      sub: 'Casual dresses',
      color: 'red',
      styles: const <String>['casual', 'smart_casual'],
    );
ClothingItem get sneakers => item(
      id: 'sneakers',
      parent: 'Footwear',
      sub: 'Sneakers',
      color: 'white',
      styles: const <String>['casual', 'streetwear'],
    );
ClothingItem get loafers => item(
      id: 'loafers',
      parent: 'Footwear',
      sub: 'Loafers',
      color: 'brown',
      styles: const <String>['formal', 'smart_casual'],
    );
ClothingItem get boots => item(
      id: 'boots',
      parent: 'Footwear',
      sub: 'Boots',
      color: 'brown',
      styles: const <String>['casual'],
    );
ClothingItem get sandals => item(
      id: 'sandals',
      parent: 'Footwear',
      sub: 'Sandals',
      color: 'tan',
      styles: const <String>['casual'],
    );

void main() {
  late AffinityEngine engine;

  setUpAll(() {
    engine = AffinityEngine(
      File('assets/ml_seed_rules.json').readAsStringSync(),
    );
  });

  group('rule loading', () {
    test('exposes the documented weather conditions and weights', () {
      expect(engine.weatherConditions,
          containsAll(<String>['hot', 'warm', 'mild', 'cold', 'freezing', 'rain']));
      final weights = engine.defaultWeights;
      expect(weights.keys.toSet(), <String>{
        'w_style',
        'w_event',
        'w_weather',
        'w_color',
        'w_category',
      });
      final total = weights.values.fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(1.0, 1e-9));
    });
  });

  group('structural validation', () {
    test('accepts the four canonical templates', () {
      expect(engine.validStructures(<ClothingItem>[shirt, jeans, sneakers]),
          <AffinityStructure>[AffinityStructure.standard]);
      expect(
        engine.validStructures(<ClothingItem>[shirt, jeans, blazer, sneakers]),
        <AffinityStructure>[AffinityStructure.outerwearLayered],
      );
      expect(engine.validStructures(<ClothingItem>[dress, loafers]),
          <AffinityStructure>[AffinityStructure.onePiece]);
      expect(engine.validStructures(<ClothingItem>[dress, blazer, loafers]),
          <AffinityStructure>[AffinityStructure.onePieceLayered]);
    });

    test('rejects an empty candidate', () {
      expect(engine.rejectionReason(<ClothingItem>[]), isNotNull);
      final result = engine.score(items: const <ClothingItem>[]);
      expect(result.styleMatchPercent, 0);
      expect(result.isValid, isFalse);
    });

    test('rejects missing footwear', () {
      expect(
        engine.rejectionReason(<ClothingItem>[shirt, jeans]),
        contains('footwear'),
      );
    });

    test('rejects two pairs of footwear', () {
      expect(
        engine.rejectionReason(<ClothingItem>[shirt, jeans, sneakers, loafers]),
        contains('footwear'),
      );
    });

    test('rejects multiple bottoms', () {
      expect(
        engine.rejectionReason(
            <ClothingItem>[shirt, jeans, trousers, sneakers]),
        contains('more than one bottom'),
      );
    });

    test('rejects overlapping one-piece and top', () {
      expect(
        engine.rejectionReason(<ClothingItem>[dress, shirt, loafers]),
        contains('cannot be combined with a top'),
      );
    });

    test('rejects one-piece combined with a separate bottom', () {
      expect(
        engine.rejectionReason(<ClothingItem>[dress, jeans, loafers]),
        contains('separate bottom'),
      );
    });

    test('rejects two one-pieces', () {
      expect(
        engine.rejectionReason(<ClothingItem>[dress, casualDress, loafers]),
        contains('more than one dress'),
      );
    });

    test('rejects a layered outfit missing its top', () {
      expect(
        engine.rejectionReason(<ClothingItem>[jeans, blazer, sneakers]),
        contains('layered outfit needs a top'),
      );
    });

    test('rejects a candidate with no body item', () {
      expect(
        engine.rejectionReason(<ClothingItem>[sneakers]),
        isNotNull,
      );
    });
  });

  group('score bounds', () {
    final candidates = <List<ClothingItem>>[
      <ClothingItem>[shirt, jeans, sneakers],
      <ClothingItem>[tee, shorts, sandals],
      <ClothingItem>[sweater, jeans, boots],
      <ClothingItem>[dress, loafers],
      <ClothingItem>[dress, blazer, loafers],
      <ClothingItem>[shirt, trousers, blazer, loafers],
      <ClothingItem>[tee, jeans, hoodie, sneakers],
    ];
    final contexts = <List<String>>[
      <String>['Work', 'mild'],
      <String>['Braai', 'hot'],
      <String>['Date', 'cold'],
      <String>['Groove', 'warm'],
      <String>['Formal event', 'freezing'],
      <String>['Casual', 'rain'],
    ];

    test('every score stays within 0-100 and every component within 0-1', () {
      for (final candidate in candidates) {
        for (final context in contexts) {
          final result = engine.score(
            items: candidate,
            occasion: context[0],
            weather: context[1],
          );
          expect(result.styleMatchPercent, inInclusiveRange(0, 100));
          for (final component in <double>[
            result.style,
            result.event,
            result.weather,
            result.color,
            result.category,
          ]) {
            expect(component, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    });

    test('an invalid candidate always scores 0', () {
      final result = engine.score(items: <ClothingItem>[shirt, jeans]);
      expect(result.styleMatchPercent, 0);
      expect(result.isValid, isFalse);
      expect(result.reasons, isNotEmpty);
    });

    test('scoring is deterministic', () {
      final a = engine.score(
        items: <ClothingItem>[shirt, jeans, sneakers],
        occasion: 'Date',
        weather: 'mild',
      );
      final b = engine.score(
        items: <ClothingItem>[shirt, jeans, sneakers],
        occasion: 'Date',
        weather: 'mild',
      );
      expect(a.styleMatchPercent, b.styleMatchPercent);
    });

    test('unknown occasion or weather falls back to a neutral component', () {
      final result = engine.score(
        items: <ClothingItem>[shirt, jeans, sneakers],
        occasion: 'Not An Occasion',
        weather: 'hurricane',
      );
      expect(result.event, 0.5);
      expect(result.weather, 0.5);
    });
  });

  group('occasion ranking', () {
    final formalFit = <ClothingItem>[shirt, trousers, loafers];
    final casualFit = <ClothingItem>[tee, shorts, sandals];

    test('formal fit wins a formal occasion and loses a street occasion', () {
      final formalForEvent =
          engine.score(items: formalFit, occasion: 'Formal event');
      final casualForEvent =
          engine.score(items: casualFit, occasion: 'Formal event');
      expect(formalForEvent.event, greaterThan(casualForEvent.event));
      expect(formalForEvent.styleMatchPercent,
          greaterThan(casualForEvent.styleMatchPercent));

      final formalForGroove = engine.score(items: formalFit, occasion: 'Groove');
      final casualForGroove =
          engine.score(items: casualFit, occasion: 'Groove');
      expect(casualForGroove.event, greaterThan(formalForGroove.event));
    });

    test('changing the occasion changes the overall score', () {
      final best = engine.score(items: formalFit, occasion: 'Formal event');
      final worst = engine.score(items: formalFit, occasion: 'Groove');
      expect(best.styleMatchPercent, greaterThan(worst.styleMatchPercent));
    });

    test('an explicit target style is respected', () {
      final formal = engine.score(
        items: <ClothingItem>[shirt, trousers, loafers],
        targetStyle: 'formal',
      );
      final casual = engine.score(
        items: <ClothingItem>[tee, shorts, sandals],
        targetStyle: 'formal',
      );
      expect(formal.style, 1.0);
      expect(casual.style, 0.0);
    });
  });

  group('weather ranking', () {
    final lightFit = <ClothingItem>[tee, shorts, sandals];
    final warmFit = <ClothingItem>[sweater, jeans, boots];

    test('light items win hot weather and heavy items win freezing', () {
      final hot = engine.score(items: lightFit, weather: 'hot');
      final hotWarm = engine.score(items: warmFit, weather: 'hot');
      expect(hot.weather, greaterThan(hotWarm.weather));
      expect(hot.styleMatchPercent, greaterThan(hotWarm.styleMatchPercent));

      final freezing = engine.score(items: warmFit, weather: 'freezing');
      final freezingLight = engine.score(items: lightFit, weather: 'freezing');
      expect(freezing.weather, greaterThan(freezingLight.weather));
    });

    test('a waterproof outer layer wins rain', () {
      final rainLayered =
          engine.score(items: <ClothingItem>[tee, jeans, hoodie, sneakers],
              weather: 'rain');
      final rainPlain = engine.score(
          items: <ClothingItem>[tee, jeans, sneakers], weather: 'rain');
      expect(rainLayered.weather, greaterThan(rainPlain.weather));
    });

    test('weather changes the score for the same outfit', () {
      final hot = engine.score(
          items: <ClothingItem>[tee, shorts, sandals], weather: 'hot');
      final cold = engine.score(
          items: <ClothingItem>[tee, shorts, sandals], weather: 'freezing');
      expect(hot.styleMatchPercent, greaterThan(cold.styleMatchPercent));
    });
  });

  group('colour harmony', () {
    test('an all-neutral fit outscores a warm/cool mix', () {
      final neutralFit = engine.score(
        items: <ClothingItem>[shirt, trousers, loafers],
      );
      final loudFit = engine.score(items: <ClothingItem>[
        item(
          id: 'warm-top',
          parent: 'Tops',
          sub: 'T-shirts',
          color: 'red',
        ),
        item(
          id: 'cool-bottom',
          parent: 'Bottoms',
          sub: 'Jeans',
          color: 'green',
        ),
        sneakers,
      ]);
      expect(neutralFit.color, greaterThan(loudFit.color));
    });
  });

  group('explainability and feedback hooks', () {
    test('a scored outfit returns reasons and contributing rule keys', () {
      final result = engine.score(
        items: <ClothingItem>[shirt, jeans, sneakers],
        occasion: 'Work',
        weather: 'mild',
      );
      expect(result.isValid, isTrue);
      expect(result.reasons, isNotEmpty);
      expect(result.contributions, isNotEmpty);
      expect(
        result.contributions.any((key) => key.startsWith('cc-')),
        isTrue,
        reason: 'category rule should be tracked for feedback adaptation',
      );
      expect(
        result.contributions.any((key) => key.startsWith('style:')),
        isTrue,
        reason: 'style/event rule should be tracked for feedback adaptation',
      );
    });
  });
}


