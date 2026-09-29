import 'dart:convert';
import 'dart:io';

import 'package:dls_app/core/engine/affinity_engine.dart';
import 'package:dls_app/core/engine/feedback_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late AffinityEngine engine;

  FeedbackStore newStore() =>
      FeedbackStore(engine: engine, directoryProvider: () async => tempDir);

  setUpAll(() {
    engine = AffinityEngine(
      File('assets/ml_seed_rules.json').readAsStringSync(),
    );
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dls_feedback');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('adaptation formula', () {
    test('matches the documented worked examples', () {
      expect(FeedbackStore.adapt(0.60, 1.0), closeTo(0.64, 1e-9));
      expect(FeedbackStore.adapt(0.60, 0.0), closeTo(0.54, 1e-9));
    });

    test('clamps into [0.0, 1.0]', () {
      expect(FeedbackStore.adapt(1.0, 1.0), 1.0);
      expect(FeedbackStore.adapt(0.0, 0.0), 0.0);
      // Out-of-range feedback is defensive: the store clamps before calling.
      expect(FeedbackStore.adapt(0.0, 5.0), closeTo(0.5, 1e-9));
      expect(FeedbackStore.adapt(1.0, -5.0), closeTo(0.4, 1e-9));
      expect(FeedbackStore.adapt(1.0, -100.0), 0.0);
    });
  });

  group('normalisation', () {
    test('scales a vector to sum 1.0', () {
      final n = FeedbackStore.normalize(<String, double>{'a': 2.0, 'b': 2.0});
      expect(n['a'], closeTo(0.5, 1e-9));
      expect(n['b'], closeTo(0.5, 1e-9));
    });

    test('keeps every value inside [0, 1]', () {
      final n = FeedbackStore.normalize(<String, double>{'a': 5.0, 'b': 0.2});
      for (final value in n.values) {
        expect(value, inInclusiveRange(0.0, 1.0));
      }
    });

    test('an all-zero vector becomes uniform and still sums to 1.0', () {
      final n = FeedbackStore.normalize(
          <String, double>{'a': 0.0, 'b': 0.0, 'c': 0.0});
      expect(n['a'], closeTo(1 / 3, 1e-9));
      expect(n.values.fold<double>(0, (x, y) => x + y), closeTo(1.0, 1e-9));
    });
  });

  group('initialisation', () {
    test('seeds from the rules matrix when no file exists', () async {
      final weights = await newStore().load();
      expect(weights.values.keys.toSet(), engine.defaultWeights.keys.toSet());
      for (final key in engine.defaultWeights.keys) {
        expect(weights.values[key], closeTo(engine.defaultWeights[key]!, 1e-9));
      }
      expect(weights.total, closeTo(1.0, 1e-9));
      expect(weights.feedbackCount, 0);
    });

    test('falls back to built-in defaults without an engine', () async {
      final store = FeedbackStore(directoryProvider: () async => tempDir);
      final weights = await store.load();
      expect(weights.values.keys.toSet(),
          FeedbackStore.fallbackDefaults.keys.toSet());
      expect(weights.total, closeTo(1.0, 1e-9));
    });
  });

  group('contribution mapping', () {
    test('maps each contribution key to the right dimensions', () {
      expect(dimensionsForContribution('cc-01'),
          unorderedEquals(<String>['w_category']));
      expect(dimensionsForContribution('style:formal|event:work'),
          unorderedEquals(<String>['w_style', 'w_event']));
      expect(dimensionsForContribution('weather:hot|class:top_light'),
          unorderedEquals(<String>['w_weather']));
      expect(dimensionsForContribution('color:neutral|warm'),
          unorderedEquals(<String>['w_color']));
      expect(dimensionsForContribution('mystery'), isEmpty);
    });
  });

  group('applyFeedback', () {
    test('like raises only implicated dimensions and renormalises', () async {
      final store = newStore();
      final before = await store.load();
      final after = await store.applyFeedback(
        contributions: const <String>['style:formal|event:work'],
        feedback: 1.0,
      );
      expect(after.values['w_style'], greaterThan(before.values['w_style']!));
      expect(after.values['w_event'], greaterThan(before.values['w_event']!));
      expect(after.values['w_weather'], lessThan(before.values['w_weather']!));
      expect(after.total, closeTo(1.0, 1e-9));
      expect(after.feedbackCount, 1);
    });

    test('dislike lowers only implicated dimensions', () async {
      final store = newStore();
      final before = await store.load();
      final after = await store.applyFeedback(
        contributions: const <String>['cc-01'],
        feedback: 0.0,
      );
      expect(after.values['w_category'], lessThan(before.values['w_category']!));
      expect(after.total, closeTo(1.0, 1e-9));
    });

    test('an empty contribution set changes nothing', () async {
      final after = await newStore()
          .applyFeedback(contributions: const <String>[], feedback: 1.0);
      expect(after.feedbackCount, 0);
      expect(after.total, closeTo(1.0, 1e-9));
    });

    test('repeated dislike never breaks the bounds or the sum', () async {
      final store = newStore();
      var weights = await store.load();
      for (var i = 0; i < 200; i++) {
        weights = await store.applyFeedback(
          contributions: const <String>[
            'style:formal|event:work',
            'cc-01',
            'weather:hot|class:top_light',
            'color:neutral|neutral',
          ],
          feedback: 0.0,
        );
        for (final value in weights.values.values) {
          expect(value, inInclusiveRange(0.0, 1.0));
        }
        expect(weights.total, closeTo(1.0, 1e-6));
      }
      expect(weights.feedbackCount, 200);
    });
  });

  group('persistence', () {
    test('writes atomically and leaves no temp file behind', () async {
      await newStore()
          .applyFeedback(contributions: const <String>['cc-01'], feedback: 1.0);
      final target =
          File('${tempDir.path}${Platform.pathSeparator}user_weights.json');
      expect(target.existsSync(), isTrue);
      expect(
        File('${target.path}${FeedbackStore.tempSuffix}').existsSync(),
        isFalse,
      );
      final decoded = jsonDecode(await target.readAsString());
      expect(decoded['weights'], isA<Map<String, dynamic>>());
      expect(decoded['feedbackCount'], 1);
    });

    test('a new store instance reloads the persisted weights', () async {
      final saved = await newStore().applyFeedback(
        contributions: const <String>['cc-01'],
        feedback: 1.0,
      );
      final loaded = await newStore().load();
      expect(loaded.feedbackCount, saved.feedbackCount);
      for (final key in saved.values.keys) {
        expect(loaded.values[key], closeTo(saved.values[key]!, 1e-9));
      }
    });

    test('a corrupt file falls back to defaults instead of throwing', () async {
      File('${tempDir.path}${Platform.pathSeparator}user_weights.json')
          .writeAsStringSync('{not json');
      final weights = await newStore().load();
      expect(weights.total, closeTo(1.0, 1e-9));
    });
  });
}

