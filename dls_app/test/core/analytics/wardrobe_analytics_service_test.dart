import 'package:dls_app/core/analytics/analytics_store.dart';
import 'package:dls_app/core/analytics/wardrobe_analytics_service.dart';
import 'package:dls_app/models/clothing_item.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Builds a wardrobe with [tops] tops and [bottoms] bottoms.
List<ClothingItem> _balanced(int tops, int bottoms) => <ClothingItem>[
      for (var i = 0; i < tops; i++)
        _item('top-$i',
            parent: 'Tops',
            type: 'top',
            styles: <String>['casual', 'formal', 'street', 'sport']),
      for (var i = 0; i < bottoms; i++)
        _item('bot-$i',
            parent: 'Bottoms',
            type: 'bottom',
            styles: <String>['casual', 'formal', 'street', 'sport']),
    ];

void main() {
  const service = WardrobeAnalyticsService();
  final now = DateTime(2026, 6, 30);

  group('colorBreakdown', () {
    test('is empty for an empty wardrobe', () {
      final result = service.colorBreakdown(const <ClothingItem>[]);
      expect(result.isEmpty, isTrue);
      expect(result.neutral, 0);
    });

    test('splits neutral / warm / cool and ignores unknown groups', () {
      final result = service.colorBreakdown(<ClothingItem>[
        _item('a', colorGroup: 'neutral'),
        _item('b', colorGroup: 'neutral'),
        _item('c', colorGroup: 'warm'),
        _item('d', colorGroup: 'cool'),
        _item('e', colorGroup: 'chartreuse'), // unrecognised
      ]);
      // 4 recognised groups -> 0.5 / 0.25 / 0.25; total still counts all 5.
      expect(result.neutral, closeTo(0.5, 1e-9));
      expect(result.warm, closeTo(0.25, 1e-9));
      expect(result.cool, closeTo(0.25, 1e-9));
      expect(result.total, 5);
    });

    test('never reports 100% when no colour is recognised', () {
      final result = service.colorBreakdown(<ClothingItem>[
        _item('a', colorGroup: 'neon'),
        _item('b', colorGroup: 'neon'),
      ]);
      expect(result.neutral + result.warm + result.cool, 0);
    });
  });

  group('categoryBreakdown', () {
    test('always exposes every display row, even at zero', () {
      final result = service.categoryBreakdown(<ClothingItem>[
        _item('a', parent: 'Tops', type: 'top'),
      ]);
      for (final key in CategoryBreakdown.displayOrder) {
        expect(result.counts.containsKey(key), isTrue);
      }
      expect(result.shareOf('Footwear'), 0);
      expect(result.shareOf('Tops'), 1.0);
    });
  });

  group('utilization', () {
    test('an untouched wardrobe is 0% and fully unworn', () {
      final report = service.utilization(_balanced(6, 2), now: now);
      expect(report.ratePercent, 0);
      expect(report.unworn.length, 8);
      expect(report.mostWorn, isEmpty);
    });

    test('counts items worn inside the window', () {
      final report = service.utilization(<ClothingItem>[
        _item('a',
            wearCount: 2, lastWorn: now.subtract(const Duration(days: 3))),
        _item('b',
            wearCount: 1, lastWorn: now.subtract(const Duration(days: 200))),
        _item('c'),
      ], windowDays: 30, now: now);

      expect(report.wornInWindow, 1);
      expect(report.ratePercent, closeTo(100 / 3, 0.01));
      expect(report.underutilized.single.id, 'b');
      expect(report.unworn.single.id, 'c');
    });

    test('most worn is ordered by wear count', () {
      final report = service.utilization(<ClothingItem>[
        _item('a', wearCount: 1, lastWorn: now),
        _item('b', wearCount: 5, lastWorn: now),
        _item('c', wearCount: 3, lastWorn: now),
      ], now: now);
      expect(
        report.mostWorn.map((i) => i.id).toList(),
        <String>['b', 'c', 'a'],
      );
    });

    test('applyWear -> utilization round trip moves an item from unworn to '
        'mostWorn - the real path behind the "Wear This" action', () {
      final wardrobe = <ClothingItem>[_item('a'), _item('b')];
      final before = service.utilization(wardrobe, now: now);
      expect(before.unworn.map((i) => i.id), contains('a'));
      expect(before.mostWorn, isEmpty);

      final entry = OutfitLogEntry(
        timestamp: now,
        occasion: 'Work',
        weather: 'Warm',
        styleMatchPercent: 80,
        scoreStyle: 0.5,
        scoreEvent: 0.5,
        scoreWeather: 0.5,
        scoreColor: 0.5,
        scoreCategory: 0.5,
        itemIds: const <String>['a'],
      );
      final worn = AnalyticsStore.applyWear(wardrobe, entry, wornAt: now);

      final after = service.utilization(worn, now: now);
      expect(after.mostWorn.map((i) => i.id), contains('a'));
      expect(after.unworn.map((i) => i.id), isNot(contains('a')));
      expect(after.unworn.map((i) => i.id), contains('b'));
    });

    test('a 90-day window is more forgiving than 30', () {
      final wardrobe = <ClothingItem>[
        _item('old',
            wearCount: 1, lastWorn: now.subtract(const Duration(days: 45))),
        _item('new', wearCount: 1, lastWorn: now),
      ];
      expect(
          service.utilization(wardrobe, windowDays: 30, now: now).wornInWindow, 1);
      expect(
          service.utilization(wardrobe, windowDays: 90, now: now).wornInWindow, 2);
    });
  });

  group('health', () {
    test('an empty wardrobe scores zero', () {
      expect(service.health(const <ClothingItem>[]).score, 0);
    });

    test('a 3:1 wardrobe scores full marks on balance', () {
      final health = service.health(_balanced(6, 2));
      expect(health.topsToBottomsRatio, closeTo(3.0, 1e-9));
      expect(health.categoryBalanceScore, 100);
      expect(health.score, greaterThan(80));
    });

    test('top-heavy wardrobes score below a balanced one', () {
      final topHeavy = service.health(_balanced(12, 2));
      final balanced = service.health(_balanced(6, 2));
      expect(topHeavy.categoryBalanceScore,
          lessThan(balanced.categoryBalanceScore));
      expect(topHeavy.notes, isNotEmpty);
    });

    test('no bottoms at all scores zero balance and says so', () {
      final health = service.health(_balanced(5, 0));
      expect(health.categoryBalanceScore, 0);
      expect(health.topsToBottomsRatio, isNull);
      expect(health.notes.first, contains('bottoms'));
    });

    test('the score always stays within 0-100', () {
      for (final ratio in <List<int>>[
        <int>[1, 1],
        <int>[50, 1],
        <int>[1, 40],
        <int>[3, 1],
      ]) {
        expect(service.health(_balanced(ratio[0], ratio[1])).score,
            inInclusiveRange(0, 100));
      }
    });
  });

  group('style scoring', () {
    OutfitLogEntry log(int percent, DateTime at, List<String> ids) =>
        OutfitLogEntry(
          timestamp: at,
          occasion: 'Work',
          weather: '',
          styleMatchPercent: percent,
          scoreStyle: 0,
          scoreEvent: 0,
          scoreWeather: 0,
          scoreColor: 0,
          scoreCategory: 0,
          itemIds: ids,
        );

    test('average is zero with no history', () {
      expect(service.averageStyleScore(const <OutfitLogEntry>[]), 0);
      expect(service.totalOutfitsGenerated(const <OutfitLogEntry>[]), 0);
    });

    test('averages the style match percent', () {
      final entries = <OutfitLogEntry>[
        log(60, now, <String>['a']),
        log(80, now, <String>['a']),
        log(100, now, <String>['a']),
      ];
      expect(service.averageStyleScore(entries), closeTo(80, 1e-9));
    });

    test('counts distinct garment combinations, not raw logs', () {
      final entries = <OutfitLogEntry>[
        log(80, now, <String>['a']),
        log(80, now, <String>['a']), // same ids -> same outfit
        log(70, now, <String>['a', 'b']),
      ];
      expect(service.totalOutfitsGenerated(entries), 2);
    });

    test('trend buckets by week and returns oldest first', () {
      final trend = service.styleScoreTrend(<OutfitLogEntry>[
        log(50, DateTime(2026, 6, 1), <String>['a']),
        log(70, DateTime(2026, 6, 3), <String>['a']), // same week
        log(90, DateTime(2026, 6, 15), <String>['a']), // next week
      ]);
      expect(trend.length, 2);
      expect(trend.first.averageScore, closeTo(60, 1e-9));
      expect(trend.last.averageScore, closeTo(90, 1e-9));
      expect(trend.first.weekStart.isBefore(trend.last.weekStart), isTrue);
    });

    test('trend weeks start on a Monday', () {
      final trend = service.styleScoreTrend(<OutfitLogEntry>[
        log(80, DateTime(2026, 6, 17), <String>['a']), // a Wednesday
      ]);
      expect(trend.single.weekStart.weekday, DateTime.monday);
    });

    test('trend is capped to the most recent weeks', () {
      final entries = <OutfitLogEntry>[
        for (var w = 0; w < 12; w++)
          log(50 + w, DateTime(2026, 1, 5).add(Duration(days: 7 * w)),
              <String>['a']),
      ];
      expect(service.styleScoreTrend(entries, maxWeeks: 4).length, 4);
    });
  });
}
