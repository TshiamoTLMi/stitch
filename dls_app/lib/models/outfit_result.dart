import 'clothing_item.dart';

class OutfitResult {
  OutfitResult({
    required this.top,
    required this.bottom,
    required this.shoes,
    required this.accessory,
    this.outerwear,
    this.onePiece,
    this.accessories = const <ClothingItem>[],
    required this.score,
    required this.reasoning,
  });

  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final ClothingItem? accessory;
  final ClothingItem? outerwear;
  final ClothingItem? onePiece;
  final List<ClothingItem> accessories;
  final int score;
  final List<String> reasoning;

  bool get isOnePiece => onePiece != null;

  bool get isValid => (top != null || bottom != null || onePiece != null) && shoes != null;

  Map<String, dynamic> toJson() {
    return {
      'top_id': top?.id,
      'bottom_id': bottom?.id,
      'shoes_id': shoes?.id,
      'accessory_id': accessory?.id,
      'outerwear_id': outerwear?.id,
      'one_piece_id': onePiece?.id,
      'accessory_ids': accessories.map((item) => item.id).toList(),
      'score': score,
      'reasoning': reasoning,
    };
  }
}
