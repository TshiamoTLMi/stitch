import 'clothing_item.dart';

class Outfit {
  const Outfit({
    this.top,
    this.bottom,
    this.shoes,
    this.outerwear,
    this.accessories = const <ClothingItem>[],
    required this.styleScore,
    required this.reason,
  });

  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final ClothingItem? outerwear;
  final List<ClothingItem> accessories;
  final int styleScore;
  final String reason;

  bool get isComplete => top != null && bottom != null && shoes != null;

  List<String> get missingItems => <String>[
        if (top == null) 'top',
        if (bottom == null) 'bottom',
        if (shoes == null) 'shoes',
      ];

  Map<String, dynamic> toJson() {
    Map<String, dynamic>? itemJson(ClothingItem? item) {
      if (item == null) return null;
      return <String, dynamic>{
        'id': item.id,
        'category': item.subcategory,
        'categoryType': item.categoryType,
        'color': item.color,
        'colorGroup': item.colorGroup,
        'styleTags': item.styleTags,
        'imageUrl': item.imageUrl,
      };
    }

    return <String, dynamic>{
      'top': itemJson(top),
      'bottom': itemJson(bottom),
      'shoes': itemJson(shoes),
      'outerwear': itemJson(outerwear),
      'accessories': accessories.map(itemJson).toList(),
      'styleScore': styleScore,
      'reason': reason,
      'missingItems': missingItems,
    };
  }
}
