import '../models/clothing_item.dart';
import '../models/outfit.dart';
import 'wardrobe_repository.dart';

class RuleEngine {
  RuleEngine({
    WardrobeRepository? wardrobeRepository,
    List<ClothingItem> Function()? localItemsProvider,
  })  : _wardrobeRepository = wardrobeRepository,
        _localItemsProvider = localItemsProvider;

  final WardrobeRepository? _wardrobeRepository;
  final List<ClothingItem> Function()? _localItemsProvider;

  List<Outfit> generateTop3(
    String occasion,
    String mood,
    String weather, {
    bool genderFilterEnabled = false,
    String? gender,
  }) {
    final localItems = _localItemsProvider?.call() ??
        _wardrobeRepository?.cachedItems ??
        const <ClothingItem>[];
    var cleanItems = localItems.where((item) => item.isClean).toList();

    if (genderFilterEnabled && gender != null && gender.trim().isNotEmpty) {
      final requestedGender = gender.trim().toLowerCase();
      cleanItems = cleanItems
          .where((item) =>
              item.gender.toLowerCase() == 'unisex' ||
              item.gender.toLowerCase() == requestedGender)
          .toList();
    }

    final tops = _occasionPool(
      cleanItems.where((item) => _isTop(item)).toList(),
      occasion,
    );
    final bottoms = _occasionPool(
      cleanItems.where((item) => _isBottom(item)).toList(),
      occasion,
    );
    final shoes = _occasionPool(
      cleanItems.where((item) => _isShoes(item)).toList(),
      occasion,
    );
    final outerwear = cleanItems.where(_isOuterwear).toList()
      ..sort((a, b) => _itemScore(b, occasion, mood, weather)
          .compareTo(_itemScore(a, occasion, mood, weather)));
    final accessories = cleanItems.where(_isAccessory).toList()
      ..sort((a, b) => _itemScore(b, occasion, mood, weather)
          .compareTo(_itemScore(a, occasion, mood, weather)));

    _sortByScore(tops, occasion, mood, weather);
    _sortByScore(bottoms, occasion, mood, weather);
    _sortByScore(shoes, occasion, mood, weather);

    return List<Outfit>.generate(3, (index) {
      final top = _pick(tops, index);
      final bottom = _pick(bottoms, index);
      final shoe = _pick(shoes, index);
      final jacket =
          _needsOuterwear(weather, occasion) ? _pick(outerwear, index) : null;
      final selectedAccessories = <ClothingItem>[
        if (accessories.isNotEmpty) accessories[index % accessories.length],
        if (accessories.length > 1)
          accessories[(index + 1) % accessories.length],
      ];
      final selected = <ClothingItem?>[
        top,
        bottom,
        shoe,
        jacket,
        ...selectedAccessories
      ].whereType<ClothingItem>().toList();
      final rawScore = selected.isEmpty
          ? 0
          : (selected
                      .map((item) => _itemScore(item, occasion, mood, weather))
                      .reduce((a, b) => a + b) /
                  selected.length)
              .round();
      final styleScore = (rawScore + _harmonyScore(selected)).clamp(0, 100);
      final missing = <String>[
        if (top == null) 'top',
        if (bottom == null) 'bottom',
        if (shoe == null) 'shoes',
      ];
      final reason = missing.isEmpty
          ? 'A $mood $occasion fit with ${_harmonyLabel(selected)} colour harmony.'
          : 'Basic mode found a partial fit. Missing: ${missing.join(', ')}.';

      return Outfit(
        top: top,
        bottom: bottom,
        shoes: shoe,
        outerwear: jacket,
        accessories: selectedAccessories,
        styleScore: styleScore,
        reason: reason,
      );
    });
  }

  List<ClothingItem> _occasionPool(List<ClothingItem> items, String occasion) {
    final matches =
        items.where((item) => _matchesOccasion(item, occasion)).toList();
    return matches.isEmpty ? items : matches;
  }

  void _sortByScore(
      List<ClothingItem> items, String occasion, String mood, String weather) {
    items.sort((a, b) => _itemScore(b, occasion, mood, weather)
        .compareTo(_itemScore(a, occasion, mood, weather)));
  }

  ClothingItem? _pick(List<ClothingItem> items, int index) {
    if (items.isEmpty) return null;
    return items[index % items.length];
  }

  int _itemScore(
      ClothingItem item, String occasion, String mood, String weather) {
    var score = 0;
    if (_matchesOccasion(item, occasion)) score += 20;
    if (_matchesMood(item, mood)) score += 15;
    if (_matchesWeather(item, weather)) score += 15;
    if (_isCoreCategory(item) || _isOuterwear(item) || _isAccessory(item)) {
      score += 10;
    }
    return score;
  }

  bool _matchesOccasion(ClothingItem item, String occasion) {
    final tags = _normalizedTags(item);
    final expected = switch (occasion.trim().toLowerCase()) {
      'work' => {'formal', 'smartcasual', 'businesscasual'},
      'date' => {'smartcasual', 'casual', 'formal'},
      'groove' => {'streetwear', 'smartcasual', 'casual'},
      'braai' => {'casual', 'streetwear'},
      'event' => {'formal', 'smartcasual'},
      _ => <String>{occasion.toLowerCase()},
    };
    return tags.any(expected.contains);
  }

  bool _matchesMood(ClothingItem item, String mood) {
    final color = item.color.toLowerCase();
    final group = item.colorGroup.toLowerCase();
    final tags = _normalizedTags(item);
    return switch (mood.trim().toLowerCase()) {
      'minimal' => _neutralColors.any(color.contains) || group == 'neutral',
      'clean drip' =>
        {'white', 'cream', 'pastel', 'lightblue'}.any(color.contains),
      'street flex' => tags.contains('streetwear') || _isShoes(item),
      'soft life' =>
        {'olive', 'brown', 'beige', 'sand', 'earth'}.any(color.contains) ||
            group == 'earth',
      _ => false,
    };
  }

  bool _matchesWeather(ClothingItem item, String weather) {
    final value = weather.trim().toLowerCase();
    final category = item.subcategory.toLowerCase();
    if (value == 'cold' || value == 'rainy') {
      return _isOuterwear(item) ||
          category.contains('boot') ||
          category.contains('trouser');
    }
    if (value == 'hot') {
      return category.contains('short') ||
          category.contains('linen') ||
          _isTop(item);
    }
    return _isTop(item) || _isAccessory(item);
  }

  int _harmonyScore(List<ClothingItem> items) {
    if (items.length < 2) return 0;
    var score = 0;
    for (var index = 0; index < items.length; index++) {
      for (var other = index + 1; other < items.length; other++) {
        final left = _colorGroup(items[index]);
        final right = _colorGroup(items[other]);
        if (left == 'neutral' || right == 'neutral' || left == right) {
          score += 2;
        } else if (left == 'earth' && right == 'earth') {
          score += 2;
        } else {
          score -= 1;
        }
      }
    }
    return score;
  }

  String _harmonyLabel(List<ClothingItem> items) {
    final groups = items.map(_colorGroup).toSet();
    if (groups.length == 1) return groups.first;
    if (groups.contains('neutral')) return 'balanced neutral';
    if (groups.every((group) => group == 'earth')) return 'earth-tone';
    return 'easy-to-wear';
  }

  Set<String> _normalizedTags(ClothingItem item) => item.styleTags
      .map((tag) => tag.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ''))
      .toSet();

  String _colorGroup(ClothingItem item) {
    final group = item.colorGroup.trim().toLowerCase();
    if (group.isNotEmpty) return group;
    if (_neutralColors.any(item.color.toLowerCase().contains)) return 'neutral';
    return 'other';
  }

  bool _isCoreCategory(ClothingItem item) =>
      _isTop(item) || _isBottom(item) || _isShoes(item);

  bool _isTop(ClothingItem item) =>
      item.categoryType.toLowerCase() == 'top' && !_isOuterwear(item);

  bool _isBottom(ClothingItem item) =>
      item.categoryType.toLowerCase() == 'bottom' ||
      {'pants', 'trousers', 'jeans', 'shorts', 'skirt'}
          .contains(item.subcategory.toLowerCase());

  bool _isShoes(ClothingItem item) =>
      item.categoryType.toLowerCase() == 'shoes' ||
      item.parentCategory.toLowerCase() == 'footwear' ||
      item.subcategory.toLowerCase().contains('shoe') ||
      item.subcategory.toLowerCase().contains('sneaker') ||
      item.subcategory.toLowerCase().contains('boot');

  bool _isOuterwear(ClothingItem item) {
    final value = '${item.parentCategory} ${item.subcategory}'.toLowerCase();
    return value.contains('outerwear') ||
        value.contains('jacket') ||
        value.contains('coat') ||
        value.contains('blazer') ||
        value.contains('cardigan');
  }

  bool _isAccessory(ClothingItem item) =>
      item.categoryType.toLowerCase() == 'accessory' ||
      item.parentCategory.toLowerCase() == 'accessories';

  bool _needsOuterwear(String weather, String occasion) =>
      weather.trim().toLowerCase() == 'cold' ||
      occasion.trim().toLowerCase() == 'work';

  static const _neutralColors = <String>{
    'black',
    'white',
    'grey',
    'gray',
    'beige',
    'cream',
    'navy'
  };
}
