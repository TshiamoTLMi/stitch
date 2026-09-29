import 'dart:convert';
import 'dart:io';

import 'package:dls_app/core/constants/wardrobe_taxonomy.dart';
import 'package:dls_app/core/engine/affinity_engine.dart';
import 'package:dls_app/core/engine/candidate_generator.dart';
import 'package:dls_app/core/services/event_outfit_suggester.dart';
import 'package:dls_app/models/clothing_item.dart';
import 'package:flutter_test/flutter_test.dart';

ClothingItem _item(String id, String parent, String sub, String color,
    List<String> styles) {
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
  late EventOutfitSuggester suggester;
  late List<ClothingItem> wardrobe;

  setUpAll(() {
    final engine =
        AffinityEngine(File('assets/ml_seed_rules.json').readAsStringSync());
    suggester = EventOutfitSuggester(
      engine: engine,
      generator: CandidateGenerator(engine: engine),
    );
    final decoded =
        jsonDecode(File('assets/seed/wardrobe_seed.json').readAsStringSync());
    final items = (decoded['items'] as List).cast<Map<String, dynamic>>();
    wardrobe = items
        .map((raw) => ClothingItem.fromMap(raw['id'] as String, raw))
        .toList();
  });

  test('loads the real matrix with normalised weights', () {
    // Rule count (127) is asserted in test/core/engine/rules_matrix_test.dart.
    final weights = suggester.engine.defaultWeights;
    expect(weights, isNotEmpty);
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    expect(total, closeTo(1.0, 1e-9), reason: 'weights must sum to 1.0');
  });

  test('every planner occasion produces ranked suggestions', () {
    for (final occasion in ['Work', 'Date', 'Groove', 'Braai', 'Event']) {
      final out = suggester.suggest(wardrobe: wardrobe, occasion: occasion);
      expect(out, isNotEmpty, reason: 'no suggestions for $occasion');
      expect(out.length, lessThanOrEqualTo(3));
      for (final line in out) {
        expect(line, startsWith('Style Match '), reason: line);
        expect(line, contains('%: '), reason: line);
      }
    }
  });

  test('style match percentages are bounded and non-increasing', () {
    final out = suggester.suggest(wardrobe: wardrobe, occasion: 'Work');
    final percents = out
        .map((line) => int.parse(
            line.substring('Style Match '.length, line.indexOf('%'))))
        .toList();
    for (final p in percents) {
      expect(p, inInclusiveRange(0, 100));
    }
    for (var i = 1; i < percents.length; i++) {
      expect(percents[i], lessThanOrEqualTo(percents[i - 1]));
    }
  });

  test('suggestions name real wardrobe pieces and carry a reason', () {
    final subs = wardrobe.map((i) => i.subcategory).toSet();
    for (final line in suggester.suggest(wardrobe: wardrobe, occasion: 'Braai')) {
      final pieces = line.substring(line.indexOf('%: ') + 3).split(' - ').first;
      for (final piece in pieces.split(' + ')) {
        expect(subs, contains(piece), reason: '$piece is not in the wardrobe');
      }
      expect(line.split(' - ').length, greaterThan(1),
          reason: 'expected a reason after "$line"');
    }
  });

  test('occasion is honoured: Work and Groove rank differently', () {
    final work = suggester.suggest(wardrobe: wardrobe, occasion: 'Work');
    final groove = suggester.suggest(wardrobe: wardrobe, occasion: 'Groove');
    expect(work, isNot(equals(groove)));
  });

  test('weather context is passed through to the engine', () {
    final warm = suggester.suggest(
        wardrobe: wardrobe, occasion: 'Event', weather: 'Hot');
    final cold = suggester.suggest(
        wardrobe: wardrobe, occasion: 'Event', weather: 'Cold');
    expect(warm, isNotEmpty);
    expect(cold, isNotEmpty);
  });

  test('an empty or too-small wardrobe yields no suggestions', () {
    expect(suggester.suggest(wardrobe: const [], occasion: 'Work'), isEmpty);
    expect(
      suggester.suggest(
        wardrobe: [_item('lonely', 'Tops', 'T-shirts', 'black', <String>['casual'])],
        occasion: 'Work',
      ),
      isEmpty,
    );
  });

  group('describe', () {
    test('renders percentage, pieces and reason', () {
      final engine =
          AffinityEngine(File('assets/ml_seed_rules.json').readAsStringSync());
      final gen = CandidateGenerator(engine: engine);
      final ranked = gen.rank(
        wardrobe: wardrobe,
        occasion: 'Work',
        limit: 1,
      );
      final line = EventOutfitSuggester.describe(ranked.first);
      expect(line, startsWith('Style Match '));
      expect(line, contains(ranked.first.items.first.subcategory));
    });
  });
}
