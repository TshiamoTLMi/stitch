import 'dart:io';

import 'package:dls_app/core/services/mock_wardrobe_seeder.dart';
import 'package:dls_app/services/wardrobe_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WardrobeRepository repository;
  late String requestedPath;

  final seedSource =
      File(MockWardrobeSeeder.seedAssetPath).readAsStringSync();

  Future<String> reader(String path) async {
    requestedPath = path;
    return seedSource;
  }

  MockWardrobeSeeder seeder({required bool development}) => MockWardrobeSeeder(
        repository: repository,
        assetReader: reader,
        developmentOverride: development,
      );

  setUp(() {
    repository = WardrobeRepository();
  });

  group('parsing', () {
    test('loads all 332 seed items into ClothingItem instances', () {
      final items = MockWardrobeSeeder.parseSeedJson(seedSource);
      expect(items.length, 332);
      for (final item in items) {
        expect(item.id, isNotEmpty);
        expect(item.parentCategory, isNotEmpty);
        expect(item.subcategory, isNotEmpty);
        expect(item.categoryType, isNotEmpty);
        expect(item.color, isNotEmpty);
        expect(item.styleTags, isNotEmpty);
        expect(item.status, 'clean');
        expect(item.imageUrl, isNotEmpty);
      }
    });

    test('every id is unique', () {
      final items = MockWardrobeSeeder.parseSeedJson(seedSource);
      expect(items.map((item) => item.id).toSet().length, items.length);
    });

    test('re-owns every item to the supplied user', () {
      final items =
          MockWardrobeSeeder.parseSeedJson(seedSource, userId: 'user-42');
      expect(items, isNotEmpty);
      expect(items.every((item) => item.userId == 'user-42'), isTrue);
    });

    test('tolerates malformed input instead of throwing', () {
      expect(MockWardrobeSeeder.parseSeedJson('{}'), isEmpty);
      expect(MockWardrobeSeeder.parseSeedJson('{"items": 5}'), isEmpty);
      expect(MockWardrobeSeeder.parseSeedJson('{"items": [1, "x", null]}'),
          isEmpty);
    });

    test('reads the bundled seed asset', () async {
      requestedPath = '';
      final items = await seeder(development: true).loadSeedItems();
      expect(requestedPath, 'assets/seed/wardrobe_seed.json');
      expect(items.length, 332);
    });
  });

  group('dev/prod gating', () {
    test('a production build never seeds the wardrobe', () async {
      final result = await seeder(development: false).seedIfEmpty();
      expect(result.seeded, isFalse);
      expect(result.itemCount, 0);
      expect(result.reason, contains('disabled outside development'));
      expect(repository.cachedItems, isEmpty);
    });

    test('production gating holds even with force', () async {
      final result =
          await seeder(development: false).seedIfEmpty(force: true);
      expect(result.seeded, isFalse);
      expect(repository.cachedItems, isEmpty);
    });

    test('a development build seeds the local wardrobe', () async {
      final result =
          await seeder(development: true).seedIfEmpty(userId: 'user-7');
      expect(result.seeded, isTrue);
      expect(result.itemCount, 332);
      expect(result.items, hasLength(332));
      expect(repository.cachedItems, hasLength(332));
      expect(repository.cachedItems.every((i) => i.userId == 'user-7'), isTrue);
    });

    test('a populated wardrobe is not re-seeded', () async {
      final dev = seeder(development: true);
      await dev.seedIfEmpty();
      final second = await dev.seedIfEmpty();
      expect(second.seeded, isFalse);
      expect(second.reason, contains('already has items'));
      expect(repository.cachedItems, hasLength(332));
    });

    test('force re-seeds without creating duplicate ids', () async {
      final dev = seeder(development: true);
      await dev.seedIfEmpty();
      final before = repository.cachedItems.length;
      final forced = await dev.seedIfEmpty(force: true);
      expect(forced.seeded, isTrue);
      expect(repository.cachedItems, hasLength(before));
      expect(
        repository.cachedItems.map((i) => i.id).toSet().length,
        before,
        reason: 'stable ids must collapse, not duplicate',
      );
    });
  });
}
