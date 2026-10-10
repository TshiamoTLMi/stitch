import 'package:flutter/foundation.dart' show compute, kIsWeb;

import '../../models/clothing_item.dart';
import 'affinity_engine.dart';
import 'outfit_theme.dart';

/// The primary outfit for the requested weather, plus a backup outfit for a
/// contrasting weather condition (for example rain when the forecast is dry).
class OutfitRecommendation {
  const OutfitRecommendation({
    this.primary,
    this.alternate,
    this.alternateWeather,
  });

  /// Best outfit for the requested weather, or null when none is possible.
  final ScoredOutfit? primary;

  /// Best outfit for [alternateWeather], distinct from [primary].
  final ScoredOutfit? alternate;

  /// Engine condition id the [alternate] was ranked for, such as `rain`.
  final String? alternateWeather;
}

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
    this.isolateThreshold = 20,
  });

  final AffinityEngine engine;

  /// Maximum items kept per slot bucket after pre-ranking.
  final int bucketCap;

  /// Maximum scored candidates retained.
  final int maxCandidates;

  /// Wardrobes smaller than this are ranked synchronously: the isolate
  /// hand-off (serialising the payload + spawning) costs more than the
  /// scoring work itself.
  final int isolateThreshold;

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
      final rankedItems = items
          .map((item) => (
                item: item,
                prior: engine.itemPrior(item,
                    occasion: occasion,
                    weather: weather,
                    targetStyle: targetStyle),
              ))
          .toList()
        ..sort((a, b) {
          final byPrior = b.prior.compareTo(a.prior);
          return byPrior != 0 ? byPrior : a.item.id.compareTo(b.item.id);
        });
      buckets[slot] = rankedItems
          .take(bucketCap)
          .map((rankedItem) => rankedItem.item)
          .toList();
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
    OutfitTheme theme = OutfitTheme.none,
    int limit = 3,
    int? candidateCap,
  }) {
    final pool =
        theme.isActive ? wardrobe.where(theme.accepts).toList() : wardrobe;
    final buckets = partition(
      pool,
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

  /// Ranks the primary outfit for [weather] and a backup outfit for the
  /// contrasting condition from [AffinityEngine.alternateWeatherFor]. The backup
  /// is never the same outfit as the primary.
  OutfitRecommendation recommend({
    required List<ClothingItem> wardrobe,
    String occasion = '',
    String? weather,
    String? targetStyle,
    OutfitTheme theme = OutfitTheme.none,
  }) {
    final primaryRanked = rank(
      wardrobe: wardrobe,
      occasion: occasion,
      weather: weather,
      targetStyle: targetStyle,
      theme: theme,
      limit: 1,
    );
    if (primaryRanked.isEmpty) return const OutfitRecommendation();
    final primary = primaryRanked.first;

    final alternateWeather = AffinityEngine.alternateWeatherFor(weather);
    final alternatives = rank(
      wardrobe: wardrobe,
      occasion: occasion,
      weather: alternateWeather,
      targetStyle: targetStyle,
      theme: theme,
      limit: 5,
    );
    ScoredOutfit? alternate;
    for (final candidate in alternatives) {
      if (candidate.id != primary.id) {
        alternate = candidate;
        break;
      }
    }

    return OutfitRecommendation(
      primary: primary,
      alternate: alternate,
      alternateWeather: alternate == null ? null : alternateWeather,
    );
  }

  // --- Background (isolate) ranking -----------------------------------------
  //
  // Only JSON-encodable values cross the isolate boundary, so the request and
  // the result are both plain maps/lists of primitives.

  static Map<String, dynamic> _encodeItem(ClothingItem item) =>
      <String, dynamic>{
        'id': item.id,
        'parentCategory': item.parentCategory,
        'subcategory': item.subcategory,
        'categoryType': item.categoryType,
        'color': item.color,
        'colorGroup': item.colorGroup,
        'styleTags': item.styleTags,
        'season': item.season,
        'status': item.status,
        'gender': item.gender,
        'imageUrl': item.imageUrl,
        'localImagePath': item.localImagePath,
        'userId': item.userId,
      };

  /// Builds the serialisable request for [rankInBackground].
  static Map<String, dynamic> buildRankingPayload({
    required String rulesJson,
    required Map<String, double> weights,
    required List<ClothingItem> wardrobe,
    required String occasion,
    String? weather,
    String? targetStyle,
    OutfitTheme theme = OutfitTheme.none,
    int limit = 3,
    int bucketCap = 4,
    int maxCandidates = 60,
    int? candidateCap,
  }) {
    return <String, dynamic>{
      'rulesJson': rulesJson,
      'weights': weights,
      'items': wardrobe.map(_encodeItem).toList(),
      'occasion': occasion,
      'weather': weather,
      'targetStyle': targetStyle,
      'theme': theme.name,
      'limit': limit,
      'bucketCap': bucketCap,
      'maxCandidates': maxCandidates,
      'candidateCap': candidateCap,
    };
  }

  /// Isolate entry point. Static so it can be passed to `compute()`.
  static Map<String, dynamic> rankInBackground(Map<String, dynamic> payload) {
    final engine = AffinityEngine(
      payload['rulesJson'] as String,
      weightOverrides: (payload['weights'] as Map?)?.cast<String, double>(),
    );
    final wardrobe = ((payload['items'] as List?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map((raw) => ClothingItem.fromMap(raw['id'] as String, raw))
        .toList();

    final ranked = CandidateGenerator(
      engine: engine,
      bucketCap: (payload['bucketCap'] as num?)?.toInt() ?? 4,
      maxCandidates: (payload['maxCandidates'] as num?)?.toInt() ?? 60,
    ).rank(
      wardrobe: wardrobe,
      occasion: (payload['occasion'] as String?) ?? '',
      weather: payload['weather'] as String?,
      targetStyle: payload['targetStyle'] as String?,
      theme: OutfitTheme.fromName(payload['theme'] as String?),
      limit: (payload['limit'] as num?)?.toInt() ?? 3,
      candidateCap: (payload['candidateCap'] as num?)?.toInt(),
    );

    return <String, dynamic>{
      'candidates': ranked.map(_encodeOutfit).toList(),
    };
  }

  static Map<String, dynamic> _encodeOutfit(ScoredOutfit outfit) =>
      <String, dynamic>{
        'structure': outfit.structure.ruleId,
        'styleMatchPercent': outfit.styleMatchPercent,
        'reasons': outfit.breakdown.reasons,
        'contributions': outfit.contributionKeys,
        'itemIds': outfit.items.map((item) => item.id).toList(),
        'components': <String, double>{
          'style': outfit.breakdown.style,
          'event': outfit.breakdown.event,
          'weather': outfit.breakdown.weather,
          'color': outfit.breakdown.color,
          'category': outfit.breakdown.category,
        },
      };

  /// Rebuilds [ScoredOutfit]s from an isolate result, resolving item ids
  /// against the wardrobe the caller passed in.
  static List<ScoredOutfit> decodeRankingResult(
    Map<String, dynamic> payload,
    List<ClothingItem> wardrobe, {
    int limit = 3,
  }) {
    final byId =
        <String, ClothingItem>{for (final item in wardrobe) item.id: item};
    final raw = (payload['candidates'] as List?) ?? const <dynamic>[];

    final results = <ScoredOutfit>[];
    for (final entry in raw.cast<Map<String, dynamic>>()) {
      final structure =
          AffinityStructure.fromRuleId(entry['structure'] as String? ?? '');
      if (structure == null) continue;

      final items = ((entry['itemIds'] as List?) ?? const <dynamic>[])
          .cast<String>()
          .map((id) => byId[id])
          .whereType<ClothingItem>()
          .toList();
      if (items.isEmpty) continue;

      final components =
          ((entry['components'] as Map?) ?? const <String, dynamic>{})
              .map((k, v) => MapEntry(k as String, (v as num).toDouble()));

      results.add(ScoredOutfit(
        structure: structure,
        items: items,
        breakdown: AffinityBreakdown(
          structure: structure,
          style: components['style'] ?? 0,
          event: components['event'] ?? 0,
          weather: components['weather'] ?? 0,
          color: components['color'] ?? 0,
          category: components['category'] ?? 0,
          styleMatchPercent: (entry['styleMatchPercent'] as num?)?.toInt() ?? 0,
          reasons: ((entry['reasons'] as List?) ?? const <dynamic>[])
              .cast<String>()
              .toList(),
          contributions:
              ((entry['contributions'] as List?) ?? const <dynamic>[])
                  .cast<String>()
                  .toList(),
        ),
      ));
    }

    if (limit > 0 && results.length > limit) return results.sublist(0, limit);
    return results;
  }

  /// Ranks on a background isolate, falling back to the synchronous path when
  /// isolates are unavailable.
  ///
  /// On web there is no isolate to hand off to: `compute()` would run the same
  /// work on the main thread anyway, so we skip the JSON round-trip entirely
  /// and rank inline. A `compute()` failure (unit tests, unsupported platform)
  /// also falls back cleanly.
  Future<List<ScoredOutfit>> rankAsync({
    required String rulesJson,
    required Map<String, double> weights,
    required List<ClothingItem> wardrobe,
    String occasion = '',
    String? weather,
    String? targetStyle,
    OutfitTheme theme = OutfitTheme.none,
    int limit = 3,
    int? candidateCap,
  }) async {
    List<ScoredOutfit> rankInline() => rank(
          wardrobe: wardrobe,
          occasion: occasion,
          weather: weather,
          targetStyle: targetStyle,
          theme: theme,
          limit: limit,
          candidateCap: candidateCap,
        );

    // Web cannot offload; small wardrobes are not worth a hand-off.
    if (kIsWeb || wardrobe.length < isolateThreshold) {
      return rankInline();
    }

    final payload = buildRankingPayload(
      rulesJson: rulesJson,
      weights: weights,
      wardrobe: wardrobe,
      occasion: occasion,
      weather: weather,
      targetStyle: targetStyle,
      theme: theme,
      limit: limit,
      bucketCap: bucketCap,
      maxCandidates: maxCandidates,
      candidateCap: candidateCap,
    );

    try {
      final result = await compute(rankInBackground, payload);
      return decodeRankingResult(result, wardrobe, limit: limit);
    } catch (_) {
      return rankInline();
    }
  }
}


