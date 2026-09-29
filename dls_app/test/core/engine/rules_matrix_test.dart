import 'dart:convert';
import 'dart:io';

import 'package:dls_app/core/constants/wardrobe_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

const _rulesPath = 'assets/ml_seed_rules.json';
const _pubspecPath = 'pubspec.yaml';

/// Occasions the DLS app actually supports (see `RecommendationService._needsFor`
/// and `EventPlannerPage`).
const _supportedEvents = <String>{
  'Work',
  'Braai',
  'Date',
  'Groove',
  'Formal event',
};

void main() {
  late Map<String, dynamic> rules;

  setUpAll(() {
    final file = File(_rulesPath);
    expect(file.existsSync(), isTrue, reason: '$_rulesPath is missing');
    rules = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  group('structure', () {
    test('parses and exposes all five scoring dimensions', () {
      expect(rules['version'], 1);
      expect(rules['categoryCompatibility'], isA<List>());
      expect(rules['styleEventAffinity'], isA<List>());
      expect(rules['weatherSuitability'], isA<Map>());
      expect(rules['colorHarmony'], isA<Map>());
      expect(rules['defaultWeights'], isA<Map>());
    });

    test('is registered as a Flutter asset in pubspec.yaml', () {
      expect(File(_pubspecPath).readAsStringSync(),
          contains('assets/ml_seed_rules.json'));
    });

    test('contains at least 100 affinity rules', () {
      final count = _countRules(rules);
      expect(count, greaterThanOrEqualTo(100), reason: 'only $count rules');
    });
  });

  group('categoryCompatibility', () {
    test('every slot and preferred item exists in the taxonomy', () {
      final parents = categoryTaxonomy.keys.toSet();
      final subcategories = categoryTaxonomy.values.expand((s) => s).toSet();

      for (final raw in rules['categoryCompatibility'] as List) {
        final rule = raw as Map<String, dynamic>;
        final required = rule['required'] as List;
        final optional = rule['optional'] as List?;
        final preferred = rule['preferredSubcategories'] as List?;
        expect(required, isNotEmpty, reason: '${rule['id']} has no required slots');

        for (final slot in <Object?>[...required, ...?optional]) {
          expect(parents, contains(slot),
              reason: 'unknown slot "$slot" in ${rule['id']}');
        }
        for (final sub in preferred ?? const <Object?>[]) {
          expect(subcategories, contains(sub),
              reason: 'unknown subcategory "$sub" in ${rule['id']}');
        }
        expect((rule['suitability'] as num).toDouble(),
            inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('styleEventAffinity', () {
    test('styles and events are valid with normalised scores', () {
      final pairs = <String>{};
      for (final raw in rules['styleEventAffinity'] as List) {
        final rule = raw as Map<String, dynamic>;
        expect(styleTagOptions, contains(rule['style']));
        expect(_supportedEvents, contains(rule['event']));
        expect((rule['score'] as num).toDouble(), inInclusiveRange(0.0, 1.0));
        pairs.add('${rule['style']}|${rule['event']}');
      }
      // Full cross-product: every style scored against every supported event.
      expect(pairs.length, styleTagOptions.length * _supportedEvents.length);
    });
  });

  group('weatherSuitability', () {
    test('conditions and garment classes align with the taxonomy', () {
      final weather = rules['weatherSuitability'] as Map<String, dynamic>;
      final conditions =
          (weather['conditions'] as List).cast<Map<String, dynamic>>();
      final conditionIds = conditions.map((c) => c['id'] as String).toSet();

      expect(conditionIds,
          containsAll(<String>['hot', 'warm', 'mild', 'cold', 'freezing', 'rain']));

      final subcategories = categoryTaxonomy.values.expand((s) => s).toSet();
      final classes = (weather['classes'] as List).cast<Map<String, dynamic>>();
      expect(classes, isNotEmpty);

      for (final cls in classes) {
        for (final sub in cls['subcategories'] as List) {
          expect(subcategories, contains(sub),
              reason: 'unknown subcategory "$sub" in ${cls['id']}');
        }
        final scores = (cls['scores'] as Map).cast<String, dynamic>();
        expect(scores.keys.toSet(), conditionIds,
            reason: '${cls['id']} must score every weather condition');
        for (final value in scores.values) {
          expect((value as num).toDouble(), inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('temperature ranges are ordered and sane', () {
      final weather = rules['weatherSuitability'] as Map<String, dynamic>;
      final temperature = (weather['conditions'] as List)
          .cast<Map<String, dynamic>>()
          .where((c) => c['kind'] == 'temperature')
          .toList();

      expect(temperature, isNotEmpty);
      for (final condition in temperature) {
        final min = (condition['tempMinC'] as num).toDouble();
        final max = (condition['tempMaxC'] as num).toDouble();
        expect(min, lessThan(max), reason: '${condition['id']} range inverted');
        expect(max, lessThanOrEqualTo(50));
        expect(min, greaterThanOrEqualTo(-40));
      }
    });
  });

  group('colorHarmony', () {
    test('matrix is complete, symmetric and normalised', () {
      final harmony = rules['colorHarmony'] as Map<String, dynamic>;
      final matrix = (harmony['matrix'] as Map).cast<String, dynamic>();

      expect(matrix.keys.toSet(), colorGroupOptions.toSet());
      for (final entry in matrix.entries) {
        final row = (entry.value as Map).cast<String, dynamic>();
        expect(row.keys.toSet(), colorGroupOptions.toSet());
        for (final cell in row.entries) {
          expect((cell.value as num).toDouble(), inInclusiveRange(0.0, 1.0));
          final mirrored = ((matrix[cell.key] as Map)[entry.key] as num).toDouble();
          expect((cell.value as num).toDouble(), closeTo(mirrored, 1e-9),
              reason: 'matrix not symmetric at ${entry.key}/${cell.key}');
        }
      }
      expect((harmony['patterns'] as List), isNotEmpty);
    });
  });

  group('defaultWeights', () {
    test('are non-negative and sum to exactly 1.0', () {
      final weights = (rules['defaultWeights'] as Map).cast<String, dynamic>();
      expect(weights.keys.toSet(), <String>{
        'w_style',
        'w_event',
        'w_weather',
        'w_color',
        'w_category',
      });

      var total = 0.0;
      for (final value in weights.values) {
        final weight = (value as num).toDouble();
        expect(weight, greaterThanOrEqualTo(0.0));
        total += weight;
      }
      expect(total, closeTo(1.0, 1e-9), reason: 'weights sum to $total');
    });
  });
}

/// Flattens every dimension into a comparable rule count.
int _countRules(Map<String, dynamic> rules) {
  final weather = rules['weatherSuitability'] as Map<String, dynamic>;
  final classCount = (weather['classes'] as List).length;
  final conditionCount = (weather['conditions'] as List).length;

  final harmony = rules['colorHarmony'] as Map<String, dynamic>;
  final matrixCells = (harmony['matrix'] as Map)
      .values
      .fold<int>(0, (sum, row) => sum + (row as Map).length);

  return (rules['categoryCompatibility'] as List).length +
      (rules['styleEventAffinity'] as List).length +
      classCount * conditionCount +
      matrixCells +
      (harmony['patterns'] as List).length +
      (rules['defaultWeights'] as Map).length;
}

