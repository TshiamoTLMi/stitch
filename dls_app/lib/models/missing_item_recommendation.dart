enum RecommendationState { missing, covered, unknown }

enum RecommendationAction { addToWardrobe, generateOutfit }

class MissingItemRecommendation {
  const MissingItemRecommendation({
    required this.need,
    required this.reason,
    required this.eventId,
    required this.eventName,
    required this.occasion,
    required this.state,
    required this.action,
    required this.dedupeKey,
  });

  final String need;
  final String reason;
  final String eventId;
  final String eventName;
  final String occasion;
  final RecommendationState state;
  final RecommendationAction action;
  final String dedupeKey;

  String get actionLabel => action == RecommendationAction.addToWardrobe
      ? 'Add to wardrobe'
      : 'Generate an outfit';

  String get stateLabel {
    switch (state) {
      case RecommendationState.missing:
        return 'Missing';
      case RecommendationState.covered:
        return 'Covered';
      case RecommendationState.unknown:
        return 'Needs more data';
    }
  }
}