import '../../models/clothing_item.dart';
import '../engine/affinity_engine.dart';
import '../engine/candidate_generator.dart';

/// Ranks event outfits with the on-device [AffinityEngine].
///
/// Replaces the legacy `OutfitBotService.generateSuggestionsForEvent`, which
/// scored items with an ad-hoc point system outside the five-variable affinity
/// pipeline. No network, no LLM.
class EventOutfitSuggester {
  const EventOutfitSuggester({required this.engine, required this.generator});

  static const String rulesAsset = 'assets/ml_seed_rules.json';

  final AffinityEngine engine;
  final CandidateGenerator generator;

  /// Loads the bundled rule matrix once and keeps it for the page's lifetime.
  static Future<EventOutfitSuggester> load() async {
    final engine = await AffinityEngine.fromAsset(rulesAsset);
    return EventOutfitSuggester(
      engine: engine,
      generator: CandidateGenerator(engine: engine),
    );
  }

  /// Ranks up to [limit] outfits for [occasion] and returns display strings.
  ///
  /// Synchronous on purpose: the engine is already loaded, the candidate set is
  /// pruned by `CandidateGenerator`, and the event list rebuilds this inside a
  /// stream builder (which cannot await).
  List<String> suggest({
    required List<ClothingItem> wardrobe,
    required String occasion,
    String? weather,
    int limit = 3,
  }) {
    final ranked = generator.rank(
      wardrobe: wardrobe,
      occasion: occasion,
      weather: weather,
      limit: limit,
    );
    return ranked.map(describe).toList();
  }

  /// One-line, user-facing summary: Style Match %, the pieces, and the reason.
  static String describe(ScoredOutfit outfit) {
    final pieces = outfit.items.map((item) => item.subcategory).join(' + ');
    final reason = outfit.reason.trim();
    final suffix = reason.isEmpty ? '' : ' - $reason';
    return 'Style Match ${outfit.styleMatchPercent}%: $pieces$suffix';
  }
}
