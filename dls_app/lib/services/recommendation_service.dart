import '../models/clothing_item.dart';
import '../models/event_model.dart';

class RecommendationService {
  List<String> buildMissingItems({
    required List<ClothingItem> wardrobe,
    required List<EventModel> upcomingEvents,
  }) {
    final categories = wardrobe.map((e) => e.categoryType).toSet();
    final suggestions = <String>{};

    for (final event in upcomingEvents) {
      switch (event.occasion.toLowerCase()) {
        case 'work':
          if (!categories.contains('shoes')) suggestions.add('Formal shoes');
          if (!categories.contains('accessory')) suggestions.add('Belt');
          if (!categories.contains('top')) suggestions.add('Ironed shirt');
          break;
        case 'formal event':
        case 'event':
          if (!categories.contains('top')) suggestions.add('Blazer');
          if (!categories.contains('shoes')) suggestions.add('Formal shoes');
          if (!categories.contains('top')) suggestions.add('Dress shirt');
          break;
        case 'braai':
          if (!categories.contains('shoes')) suggestions.add('Casual shoes');
          if (!categories.contains('bottom')) suggestions.add('Shorts');
          if (!categories.contains('top')) suggestions.add('T-shirt');
          break;
      }
    }

    return suggestions.toList()..sort();
  }
}
