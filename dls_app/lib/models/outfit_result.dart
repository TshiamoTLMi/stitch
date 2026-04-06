import 'clothing_item.dart';

class OutfitResult {
  OutfitResult({
    required this.top,
    required this.bottom,
    required this.shoes,
    required this.accessory,
    required this.score,
    required this.reasoning,
  });

  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final ClothingItem? accessory;
  final int score;
  final List<String> reasoning;

  bool get isValid => (top != null || bottom != null) && shoes != null;

  Map<String, dynamic> toJson() {
    return {
      'top_id': top?.id,
      'bottom_id': bottom?.id,
      'shoes_id': shoes?.id,
      'accessory_id': accessory?.id,
      'score': score,
      'reasoning': reasoning,
    };
  }
}
