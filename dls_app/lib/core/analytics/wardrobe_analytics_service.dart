import '../../models/clothing_item.dart';
import 'analytics_store.dart';

/// Share of the wardrobe in each colour group (each 0.0 - 1.0).
class ColorBreakdown {
  const ColorBreakdown({
    required this.neutral,
    required this.warm,
    required this.cool,
    required this.total,
  });

  final double neutral;
  final double warm;
  final double cool;
  final int total;

  /// True when no item had a recognised colour group.
  bool get isEmpty => total == 0;

  static const ColorBreakdown empty =
      ColorBreakdown(neutral: 0, warm: 0, cool: 0, total: 0);
}

/// Item counts per parent category, used by the category breakdown bars.
class CategoryBreakdown {
  const CategoryBreakdown(this.counts, this.total);

  final Map<String, int> counts;
  final int total;

  static const CategoryBreakdown empty =
      CategoryBreakdown(<String, int>{}, 0);

  /// Canonical display order for the category bars.
  static const List<String> displayOrder = <String>[
    'Tops',
    'Bottoms',
    'Outerwear',
    'Footwear',
    'Accessories',
  ];

  double shareOf(String category) =>
      total == 0 ? 0 : (counts[category] ?? 0) / total;
}

/// How much of the wardrobe has actually been worn.
class UtilizationReport {
  const UtilizationReport({
    required this.windowDays,
    required this.wornInWindow,
    required this.total,
    required this.mostWorn,
    required this.unworn,
    required this.underutilized,
  });

  final int windowDays;
  final int wornInWindow;
  final int total;

  /// Highest [ClothingItem.wearCount] first.
  final List<ClothingItem> mostWorn;

  /// Never worn at all.
  final List<ClothingItem> unworn;

  /// Worn before this window opened.
  final List<ClothingItem> underutilized;

  /// Percentage (0-100) of the wardrobe worn inside the window.
  double get ratePercent => total == 0 ? 0 : (wornInWindow / total) * 100;
}

/// Wardrobe Health Index: category balance plus versatility.
class WardrobeHealth {
  const WardrobeHealth({
    required this.score,
    required this.categoryBalanceScore,
    required this.versatilityScore,
    required this.topsToBottomsRatio,
    required this.notes,
  });

  /// Overall 0-100 index.
  final int score;

  /// How close the wardrobe is to the target 3:1 top-to-bottom ratio.
  final int categoryBalanceScore;

  /// How many distinct style tags and colour groups the wardrobe covers.
  final int versatilityScore;

  /// Actual ratio; `null` when there are no bottoms to compare against.
  final double? topsToBottomsRatio;

  /// Human-readable advice, e.g. "Add 3 more bottoms".
  final List<String> notes;

  static const WardrobeHealth empty = WardrobeHealth(
    score: 0,
    categoryBalanceScore: 0,
    versatilityScore: 0,
    topsToBottomsRatio: null,
    notes: <String>[],
  );
}

/// One point on the Style Score trend line.
class StyleTrendPoint {
  const StyleTrendPoint({
    required this.weekStart,
    required this.averageScore,
    required this.count,
  });

  final DateTime weekStart;
  final double averageScore;
  final int count;
}

/// Pure, synchronous metric calculations over the local wardrobe and log.
///
/// Deliberately free of Flutter imports so it is trivially unit-testable and
/// cheap to recompute on every rebuild.
class WardrobeAnalyticsService {
  const WardrobeAnalyticsService();

  /// Target top-to-bottom ratio for a "healthy" wardrobe.
  static const double targetTopsToBottoms = 3.0;

  /// Split a wardrobe into neutral / warm / cool shares.
  ///
  /// Unrecognised colour groups are excluded from the percentages but still
  /// counted in [ColorBreakdown.total], so an unknown colour can never inflate
  /// a share to 100%.
  ColorBreakdown colorBreakdown(List<ClothingItem> wardrobe) {
    if (wardrobe.isEmpty) return ColorBreakdown.empty;

    var neutral = 0;
    var warm = 0;
    var cool = 0;
    var known = 0;
    for (final item in wardrobe) {
      switch (item.colorGroup.trim().toLowerCase()) {
        case 'warm':
          warm++;
          known++;
          break;
        case 'cool':
          cool++;
          known++;
          break;
        case 'neutral':
          neutral++;
          known++;
          break;
        default:
          break; // Unrecognised: counted in total only.
      }
    }
    if (known == 0) {
      return ColorBreakdown(
        neutral: 0,
        warm: 0,
        cool: 0,
        total: wardrobe.length,
      );
    }
    return ColorBreakdown(
      neutral: neutral / known,
      warm: warm / known,
      cool: cool / known,
      total: wardrobe.length,
    );
  }

  /// Counts items per canonical parent category.
  CategoryBreakdown categoryBreakdown(List<ClothingItem> wardrobe) {
    if (wardrobe.isEmpty) return CategoryBreakdown.empty;

    final counts = <String, int>{};
    for (final item in wardrobe) {
      final key = _canonicalCategory(item.parentCategory);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    // Guarantee every displayed bar has a (possibly zero) row.
    for (final key in CategoryBreakdown.displayOrder) {
      counts.putIfAbsent(key, () => 0);
    }
    return CategoryBreakdown(counts, wardrobe.length);
  }

  /// Wear statistics over a rolling window (30 / 60 / 90 day presets).
  ///
  /// [QA TEST POINT] With a fresh wardrobe every item lands in `unworn` and the
  /// rate reads 0%. After logging one outfit those garments move to `mostWorn`
  /// and the 30-day rate rises.
  UtilizationReport utilization(
    List<ClothingItem> wardrobe, {
    int windowDays = 30,
    DateTime? now,
  }) {
    if (wardrobe.isEmpty) {
      return UtilizationReport(
        windowDays: windowDays,
        wornInWindow: 0,
        total: 0,
        mostWorn: const <ClothingItem>[],
        unworn: const <ClothingItem>[],
        underutilized: const <ClothingItem>[],
      );
    }

    final cutoff =
        (now ?? DateTime.now()).subtract(Duration(days: windowDays));
    var wornInWindow = 0;
    final mostWorn = <ClothingItem>[];
    final unworn = <ClothingItem>[];
    final underutilized = <ClothingItem>[];

    for (final item in wardrobe) {
      final last = item.lastWornDate;
      if (last == null || item.wearCount == 0) {
        unworn.add(item);
      } else {
        if (!last.isBefore(cutoff)) wornInWindow++;
        mostWorn.add(item);
        if (last.isBefore(cutoff)) underutilized.add(item);
      }
    }

    mostWorn.sort((a, b) {
      final byCount = b.wearCount.compareTo(a.wearCount);
      if (byCount != 0) return byCount;
      // Deterministic tie-break keeps tests reproducible.
      return (b.lastWornDate ?? DateTime(0))
          .compareTo(a.lastWornDate ?? DateTime(0));
    });
    unworn.sort((a, b) => a.id.compareTo(b.id));

    return UtilizationReport(
      windowDays: windowDays,
      wornInWindow: wornInWindow,
      total: wardrobe.length,
      mostWorn: List.unmodifiable(mostWorn),
      unworn: List.unmodifiable(unworn),
      underutilized: List.unmodifiable(underutilized),
    );
  }

  /// Blends top-to-bottom balance (60%) with versatility (40%).
  ///
  /// The balance term rewards hitting the 3:1 target and decays smoothly as the
  /// ratio drifts, so one extra pair of trousers never tanks the score.
  WardrobeHealth health(List<ClothingItem> wardrobe) {
    if (wardrobe.isEmpty) return WardrobeHealth.empty;

    var tops = 0;
    var bottoms = 0;
    for (final item in wardrobe) {
      final type = item.categoryType.trim().toLowerCase();
      if (type == 'top') {
        tops++;
      } else if (type == 'bottom') {
        bottoms++;
      }
    }

    double? ratio = bottoms == 0 ? null : tops / bottoms;
    int balance;
    final notes = <String>[];

    if (bottoms == 0) {
      balance = 0;
      notes.add('Add bottoms so tops have something to pair with.');
    } else {
      final deviation = (ratio! - targetTopsToBottoms).abs();
      // Full marks within 0.5 of target, decaying to 0 at a deviation of 4.
      balance = ((1 - (deviation / 4)) * 100).round().clamp(0, 100);
      if (deviation > 0.5) {
        notes.add(
          tops > bottoms * targetTopsToBottoms
              ? 'Add ${(tops - bottoms * targetTopsToBottoms).ceil()} more bottoms to reach the 3:1 target.'
              : 'Add ${(bottoms * targetTopsToBottoms - tops).ceil()} more tops to reach the 3:1 target.',
        );
      }
    }

    // Versatility: distinct style tags, tempered so a wardrobe cannot score
    // full marks on colour variety alone.
    final styleTags = <String>{};
    final colorGroups = <String>{};
    for (final item in wardrobe) {
      styleTags.addAll(item.styleTags.map((s) => s.trim().toLowerCase()));
      colorGroups.add(item.colorGroup.trim().toLowerCase());
    }
    final versatility =
        ((styleTags.length * 8) + (colorGroups.length * 20)).clamp(0, 100);

    final score = ((balance * 0.6) + (versatility * 0.4)).round().clamp(0, 100);

    if (styleTags.length < 4) {
      notes.add('Tag more pieces with style labels to improve versatility.');
    }

    return WardrobeHealth(
      score: score,
      categoryBalanceScore: balance,
      versatilityScore: versatility,
      topsToBottomsRatio: ratio,
      notes: notes,
    );
  }

  /// Average Style Match % across every logged outfit (0 when there are none).
  double averageStyleScore(List<OutfitLogEntry> entries) {
    if (entries.isEmpty) return 0;
    final total = entries.fold<int>(0, (sum, e) => sum + e.styleMatchPercent);
    return total / entries.length;
  }

  /// Number of distinct outfits logged (unique garment combinations).
  int totalOutfitsGenerated(List<OutfitLogEntry> entries) =>
      entries.map((e) => e.itemIds.join('|')).toSet().length;

  /// Weekly Style Score trend, oldest first, ready for a line chart.
  ///
  /// Buckets are ISO weeks starting Monday. Only weeks that actually contain a
  /// logged outfit are returned, so the chart never shows phantom zero points.
  List<StyleTrendPoint> styleScoreTrend(
    List<OutfitLogEntry> entries, {
    int maxWeeks = 8,
  }) {
    if (entries.isEmpty) return const <StyleTrendPoint>[];

    final buckets = <DateTime, List<int>>{};
    for (final entry in entries) {
      buckets
          .putIfAbsent(_weekStart(entry.timestamp), () => <int>[])
          .add(entry.styleMatchPercent);
    }

    final weeks = buckets.keys.toList()..sort();
    final recent = weeks.length > maxWeeks
        ? weeks.sublist(weeks.length - maxWeeks)
        : weeks;

    return recent.map((week) {
      final scores = buckets[week]!;
      return StyleTrendPoint(
        weekStart: week,
        averageScore: scores.reduce((a, b) => a + b) / scores.length,
        count: scores.length,
      );
    }).toList(growable: false);
  }

  /// Monday 00:00 of the week containing [date].
  static DateTime _weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// Maps loose parent-category strings onto the canonical display set.
  static String _canonicalCategory(String parent) {
    const map = <String, String>{
      'tops': 'Tops',
      'top': 'Tops',
      'bottoms': 'Bottoms',
      'bottom': 'Bottoms',
      'outerwear': 'Outerwear',
      'footwear': 'Footwear',
      'shoes': 'Footwear',
      'accessories': 'Accessories',
      'fullbody': 'Accessories',
    };
    final key = parent.trim().toLowerCase();
    return map[key] ?? parent;
  }
}
