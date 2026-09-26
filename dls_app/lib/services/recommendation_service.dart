import '../models/clothing_item.dart';
import '../models/event_model.dart';
import '../models/missing_item_recommendation.dart';

class RecommendationService {
  List<MissingItemRecommendation> buildRecommendations({
    required List<ClothingItem> wardrobe,
    required List<EventModel> upcomingEvents,
  }) {
    if (upcomingEvents.isEmpty) return const <MissingItemRecommendation>[];

    final cleanCategories = wardrobe
        .where((item) => item.isClean)
        .map((item) => item.categoryType.trim().toLowerCase())
        .where((category) => category.isNotEmpty)
        .toSet();
    final recommendations = <String, MissingItemRecommendation>{};

    for (final event in upcomingEvents) {
      final needs = _needsFor(event.occasion);
      if (needs == null) {
        final recommendation = MissingItemRecommendation(
          need: 'Event details',
          reason: '${event.name} needs a supported occasion before wardrobe gaps can be assessed.',
          eventId: event.id,
          eventName: event.name,
          occasion: event.occasion,
          state: RecommendationState.unknown,
          action: RecommendationAction.generateOutfit,
          dedupeKey: 'event-details|generateOutfit',
        );
        recommendations.putIfAbsent(recommendation.dedupeKey, () => recommendation);
        continue;
      }

      for (final need in needs) {
        final covered = cleanCategories.contains(need.category);
        final recommendation = MissingItemRecommendation(
          need: need.label,
          reason: covered
              ? '${event.name} is a ${event.occasion} occasion and your wardrobe covers this need.'
              : '${event.name} is a ${event.occasion} occasion and is missing this category.',
          eventId: event.id,
          eventName: event.name,
          occasion: event.occasion,
          state: covered ? RecommendationState.covered : RecommendationState.missing,
          action: covered
              ? RecommendationAction.generateOutfit
              : RecommendationAction.addToWardrobe,
          dedupeKey: '${need.label.toLowerCase()}|${covered ? 'generateOutfit' : 'addToWardrobe'}',
        );
        recommendations.putIfAbsent(recommendation.dedupeKey, () => recommendation);
      }
    }

    final result = recommendations.values.toList()
      ..sort((a, b) {
        final needOrder = a.need.toLowerCase().compareTo(b.need.toLowerCase());
        if (needOrder != 0) return needOrder;
        return a.dedupeKey.compareTo(b.dedupeKey);
      });
    return result;
  }

  List<String> buildMissingItems({
    required List<ClothingItem> wardrobe,
    required List<EventModel> upcomingEvents,
  }) {
    return buildRecommendations(
      wardrobe: wardrobe,
      upcomingEvents: upcomingEvents,
    )
        .where((recommendation) => recommendation.state == RecommendationState.missing)
        .map((recommendation) => recommendation.need)
        .toSet()
        .toList()
      ..sort();
  }

  List<_Need>? _needsFor(String occasion) {
    switch (occasion.trim().toLowerCase()) {
      case 'work':
        return const <_Need>[
          _Need('shoes', 'Formal shoes'),
          _Need('accessory', 'Belt'),
          _Need('top', 'Ironed shirt'),
        ];
      case 'formal event':
      case 'event':
        return const <_Need>[
          _Need('top', 'Blazer'),
          _Need('shoes', 'Formal shoes'),
        ];
      case 'braai':
        return const <_Need>[
          _Need('shoes', 'Casual shoes'),
          _Need('bottom', 'Shorts'),
          _Need('top', 'T-shirt'),
        ];
      case 'date':
      case 'groove':
        return const <_Need>[
          _Need('top', 'Statement top'),
          _Need('shoes', 'Clean shoes'),
        ];
      default:
        return null;
    }
  }
}

class _Need {
  const _Need(this.category, this.label);

  final String category;
  final String label;
}
