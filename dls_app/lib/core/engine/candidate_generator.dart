import '../../models/clothing_item.dart';
import 'affinity_engine.dart';

/// A structurally valid outfit candidate together with its computed score.
class ScoredOutfit {
  const ScoredOutfit({
    required this.structure,
    required this.items,
    required this.breakdown,
  });

  final AffinityStructure structure;
  final List<ClothingItem> items;
  final AffinityBreakdown breakdown;

  int get styleMatchPercent => breakdown.styleMatchPercent;
  List<String> get contributionKeys => breakdown.contributions;
  String get reason => breakdown.reasons.isEmpty ? '' : breakdown.reasons.first;

  /// Stable identity used for de-duplication and deterministic tie-breaking.
  String get id => items.map((item) => item.id).join('|');
}

/// Builds, validates, scores and ranks outfit candidates from a wardrobe.
///
/// Combinations are pruned twice to stay bounded on large wardrobes:
/// 1. each slot bucket is pre-ranked by [AffinityEngine.itemPrior] and capped;
/// 2. the scored list is capped at [maxCandidates].
class CandidateGenerator {
  const CandidateGenerator({
    required this.engine,
    this.bucketCap = 4,
    this.maxCandidates = 60,
  });

  final AffinityEngine engine;

  /// Maximum items kept per slot bucket after pre-ranking.
  final int bucketCap;

  /// Maximum scored candidates retained.
  final int maxCandidates;

  Map<OutfitSlot, List<ClothingItem>> partition(
    List<ClothingItem> wardrobe, {
    String occasion = '',
    String? weather,
    String? targetStyle,
  }) {
    final buckets = <OutfitSlot, List<ClothingItem>>{
      for (final slot in OutfitSlot.values) slot: <ClothingItem>[],
    };

    for (final item in wardrobe) {
      if (item.status != 'clean') continue;
      buckets[slotForParentCategory(item.parentCategory)]!.add(item);
    }

    buckets.forEach((slot, items) {
      items.sort((a, b) {
        final left = engine.itemPrior(a,
            occasion: occasion, weather: weather, targetStyle: targetStyle);
        final right = engine.itemPrior(b,
            occasion: occasion, weather: weather, targetStyle: targetStyle);
        if (left != right) return right.compareTo(left);
        return a.id.compareTo(b.id);
      });
      if (items.length > bucketCap) {
        items.removeRange(bucketCap, items.length);
      }
    });

    return buckets;
  }

  /// Builds raw item combinations for the four canonical templates.
  List<List<ClothingItem>> buildCombinations(
    Map<OutfitSlot, List<ClothingItem>> buckets,
  ) {
    final tops = buckets[OutfitSlot.top] ?? const <ClothingItem>[];
    final bottoms = buckets[OutfitSlot.bottom] ?? const <ClothingItem>[];
    final outers = buckets[OutfitSlot.outerwear] ?? const <ClothingItem>[];
    final dresses = buckets[OutfitSlot.onePiece] ?? const <ClothingItem>[];
    final shoes = buckets[OutfitSlot.shoes] ?? const <ClothingItem>[];
    final accessoryList =
        buckets[OutfitSlot.accessory] ?? const <ClothingItem>[];
    final ClothingItem? accessory =
        accessoryList.isEmpty ? null : accessoryList.first;

    final combinations = <List<ClothingItem>>[];

    for (final top in tops) {
      for (final bottom in bottoms) {
        for (final shoe in shoes) {
          combinations.add(<ClothingItem>[top, bottom, shoe]);
        }
      }
    }

    for (final top in tops) {
      for (final bottom in bottoms) {
        for (final outer in outers) {
          for (final shoe in shoes) {
            combinations.add(<ClothingItem>[top, bottom, outer, shoe]);
          }
        }
      }
    }

    for (final dress in dresses) {
      for (final shoe in shoes) {
        combinations.add(<ClothingItem>[dress, shoe]);
      }
    }

    for (final dress in dresses) {
      for (final outer in outers) {
        for (final shoe in shoes) {
          combinations.add(<ClothingItem>[dress, outer, shoe]);
        }
      }
    }

    if (accessory != null) {
      return combinations
          .map((items) => <ClothingItem>[...items, accessory])
          .toList();
    }
    return combinations;
  }

  /// Generates, validates, scores and ranks candidates.
  ///
  /// Results are sorted by [AffinityBreakdown.styleMatchPercent] descending with
  /// a stable id tie-break, so repeated runs are identical.
  List<ScoredOutfit> rank({
    required List<ClothingItem> wardrobe,
    String occasion = '',
    String? weather,
    String? targetStyle,
    int limit = 3,
    int? candidateCap,
  }) {
    final buckets = partition(
      wardrobe,
      occasion: occasion,
      weather: weather,
      targetStyle: targetStyle,
    );

    final scored = <ScoredOutfit>[];
    final seen = <String>{};

    for (final items in buildCombinations(buckets)) {
      if (engine.rejectionReason(items) != null) continue;
      final breakdown = engine.score(
        items: items,
        occasion: occasion,
        weather: weather,
        targetStyle: targetStyle,
      );
      if (!breakdown.isValid) continue;
      final outfit = ScoredOutfit(
        structure: breakdown.structure!,
        items: items,
        breakdown: breakdown,
      );
      if (!seen.add(outfit.id)) continue;
      scored.add(outfit);
    }

    scored.sort((a, b) {
      final byScore = b.styleMatchPercent.compareTo(a.styleMatchPercent);
      return byScore != 0 ? byScore : a.id.compareTo(b.id);
    });

    final cap = candidateCap ?? maxCandidates;
    final capped = scored.length > cap ? scored.sublist(0, cap) : scored;
    if (limit > 0 && capped.length > limit) return capped.sublist(0, limit);
    return capped;
  }
}

