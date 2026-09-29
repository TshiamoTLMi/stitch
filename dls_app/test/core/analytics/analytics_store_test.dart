import 'dart:convert';

import 'package:dls_app/core/analytics/analytics_store.dart';
import 'package:dls_app/core/storage/kv_store.dart';
import 'package:dls_app/models/clothing_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [KvStore] so analytics persistence can be asserted without a
/// platform directory (and without a browser).
class FakeKvStore implements KvStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

ClothingItem _item(
  String id, {
  String parent = 'Tops',
  String sub = 'T-shirts',
  String type = 'top',
  String colorGroup = 'neutral',
  List<String> styles = const <String>['casual'],
  int wearCount = 0,
  DateTime? lastWorn,
}) {
  final now = DateTime(2026, 1, 1);
  return ClothingItem(
    id: id,
    parentCategory: parent,
    subcategory: sub,
    categoryType: type,
    color: 'black',
    colorGroup: colorGroup,
    styleTags: styles,
    season: 'All Season',
    status: 'clean',
    gender: 'Unisex',
    imageUrl: '',
    userId: 'u1',
    createdAt: now,
    updatedAt: now,
    wearCount: wearCount,
    lastWornDate: lastWorn,
  );
}

OutfitLogEntry _entry({
  required DateTime at,
  int percent = 80,
  List<String> ids = const <String>['a', 'b'],
}) {
  return OutfitLogEntry(
    timestamp: at,
    occasion: 'Work',
    occasionLabel: 'Work',
    weather: 'Warm',
    styleMatchPercent: percent,
    scoreStyle: 0.5,
    scoreEvent: 0.6,
    scoreWeather: 0.4,
    scoreColor: 0.3,
    scoreCategory: 0.7,
    itemIds: ids,
  );
}

void main() {
  group('OutfitLogEntry', () {
    test('survives a JSON round trip with all five component scores', () {
      final original = _entry(at: DateTime(2026, 3, 4, 9, 30), percent: 87);
      final decoded = OutfitLogEntry.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.styleMatchPercent, 87);
      expect(decoded.scoreStyle, 0.5);
      expect(decoded.scoreEvent, 0.6);
      expect(decoded.scoreWeather, 0.4);
      expect(decoded.scoreColor, 0.3);
      expect(decoded.scoreCategory, 0.7);
      expect(decoded.itemIds, <String>['a', 'b']);
      expect(decoded.timestamp, original.timestamp);
    });
  });

  group('AnalyticsStore', () {
    late FakeKvStore kv;

    setUp(() => kv = FakeKvStore());

    test('starts empty and load() on a fresh store is safe', () async {
      final store = AnalyticsStore(store: kv);
      await store.load();
      expect(store.outfitEntries, isEmpty);
      expect(store.feedbackEntries, isEmpty);
    });

    test('persists outfits newest-first across a reload', () async {
      final store = AnalyticsStore(store: kv);
      await store.logOutfit(_entry(at: DateTime(2026, 1, 1), percent: 50));
      await store.logOutfit(_entry(at: DateTime(2026, 1, 2), percent: 90));

      final reloaded = AnalyticsStore(store: kv);
      await reloaded.load();
      expect(reloaded.outfitEntries.length, 2);
      expect(reloaded.outfitEntries.first.styleMatchPercent, 90);
    });

    test('persists feedback with its weight snapshot', () async {
      final store = AnalyticsStore(store: kv);
      await store.logFeedback(FeedbackLogEntry(
        timestamp: DateTime(2026, 2, 1),
        liked: true,
        styleMatchPercent: 77,
        weightSnapshot: const <String, double>{'w_style': 0.3},
      ));

      final reloaded = AnalyticsStore(store: kv);
      await reloaded.load();
      expect(reloaded.feedbackEntries.single.liked, isTrue);
      expect(reloaded.feedbackEntries.single.styleMatchPercent, 77);
      expect(reloaded.feedbackEntries.single.weightSnapshot['w_style'], 0.3);
    });

    test('a corrupt store degrades to empty rather than throwing', () async {
      kv.values[AnalyticsStore.fileName] = 'not json at all';
      final store = AnalyticsStore(store: kv);
      await store.load();
      expect(store.outfitEntries, isEmpty);
    });

    test('prunes to the retention cap', () async {
      final store = AnalyticsStore(store: kv);
      for (var i = 0; i < AnalyticsStore.maxOutfitEntries + 5; i++) {
        await store.logOutfit(
          _entry(at: DateTime(2026, 1, 1).add(Duration(minutes: i))),
        );
      }
      expect(
        store.outfitEntries.length,
        AnalyticsStore.maxOutfitEntries,
      );
    });

    test('applyWear increments only the garments in the outfit', () {
      final wardrobe = <ClothingItem>[
        _item('a'),
        _item('b'),
        _item('c'),
      ];
      final wornAt = DateTime(2026, 5, 1);
      final updated = AnalyticsStore.applyWear(
        wardrobe,
        _entry(at: wornAt, ids: <String>['a', 'c']),
        wornAt: wornAt,
      );

      expect(updated[0].wearCount, 1);
      expect(updated[1].wearCount, 0, reason: 'not in the outfit');
      expect(updated[2].wearCount, 1);
      expect(updated[0].lastWornDate, wornAt);
      expect(updated[1].lastWornDate, isNull);
    });
  });

  group('ClothingItem wear fields', () {
    test('default to zero / null', () {
      final item = _item('a');
      expect(item.wearCount, 0);
      expect(item.lastWornDate, isNull);
    });

    test('read back from a map with legacy snake_case keys', () {
      final item = ClothingItem.fromMap('a', <String, dynamic>{
        'wear_count': 4,
        'last_worn_date': DateTime(2026, 4, 4),
      });
      expect(item.wearCount, 4);
      expect(item.lastWornDate, DateTime(2026, 4, 4));
    });
  });
}
