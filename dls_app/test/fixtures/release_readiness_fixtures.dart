import 'package:dls_app/models/clothing_item.dart';
import 'package:dls_app/models/event_model.dart';

class ReleaseReadinessFixtures {
  static const userId = 'test-user-redacted';

  static ClothingItem clothing({
    String id = 'item-redacted',
    String categoryType = 'top',
    String subcategory = 'shirt',
    String status = 'clean',
  }) {
    final timestamp = DateTime(2026, 1, 1);
    return ClothingItem(
      id: id,
      parentCategory: 'Tops',
      subcategory: subcategory,
      categoryType: categoryType,
      color: 'black',
      colorGroup: 'neutral',
      styleTags: const <String>['casual'],
      season: 'All Season',
      status: status,
      gender: 'Unisex',
      imageUrl: '',
      userId: userId,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  static EventModel event({
    String id = 'event-redacted',
    String name = 'Test event',
    String occasion = 'Work',
    DateTime? date,
  }) {
    return EventModel(
      id: id,
      userId: userId,
      name: name,
      date: date ?? DateTime(2026, 1, 2),
      occasion: occasion,
    );
  }
}