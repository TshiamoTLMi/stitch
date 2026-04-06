import '../models/clothing_item.dart';
import '../models/event_model.dart';

class RecommendationService {
  List<String> buildMissingItems({
    required List<ClothingItem> wardrobe,
    required List<EventModel> upcomingEvents,
  }) {
    final categories = wardrobe.map((e) => e.category).toSet();
    final suggestions = <String>{};

    for (final event in upcomingEvents) {
      switch (event.occasion.toLowerCase()) {
        case 'work':
          if (!categories.contains('shoes')) suggestions.add('Formal shoes');
          if (!categories.contains('accessories')) suggestions.add('Belt');
          if (!categories.contains('shirt')) suggestions.add('Ironed shirt');
          break;
        case 'formal event':
        case 'event':
          if (!categories.contains('jacket')) suggestions.add('Blazer');
          if (!categories.contains('shoes')) suggestions.add('Formal shoes');
          if (!categories.contains('shirt')) suggestions.add('Dress shirt');
          break;
        case 'braai':
          if (!categories.contains('shoes')) suggestions.add('Casual shoes');
          if (!categories.contains('shorts')) suggestions.add('Shorts');
          if (!categories.contains('shirt')) suggestions.add('T-shirt');
          break;
      }
    }

    return suggestions.toList()..sort();
  }
}
