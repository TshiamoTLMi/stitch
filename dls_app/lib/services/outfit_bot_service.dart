import 'dart:math';

import '../models/clothing_item.dart';
import '../models/outfit_result.dart';

class OutfitBotService {
  static const neutralColors = {'black', 'white', 'grey', 'beige'};
  static const cleanDripColors = {'white', 'cream', 'pastel', 'light blue'};
  static const softLifeColors = {'olive', 'brown', 'beige', 'sand', 'earth'};

  OutfitResult generate({
    required List<ClothingItem> wardrobe,
    required String occasion,
    required String mood,
    required String weather,
  }) {
    final cleanItems = wardrobe.where((item) => item.isClean).toList();
    if (cleanItems.isEmpty) {
      return OutfitResult(
        top: null,
        bottom: null,
        shoes: null,
        accessory: null,
        score: 0,
        reasoning: const [
          'No clean items available.',
          'Mark items as clean to generate outfit suggestions.',
        ],
      );
    }

    final tops = cleanItems.where((item) => _isTop(item.category)).toList();
    final bottoms = cleanItems.where((item) => _isBottom(item.category)).toList();
    final dresses = cleanItems.where((item) => item.category == 'dress').toList();
    final shoes = cleanItems.where((item) => _isShoes(item.category)).toList();
    final accessories =
        cleanItems.where((item) => _isAccessory(item.category)).toList();

    final scored = cleanItems
        .map((item) => MapEntry(item, _scoreItem(item, occasion, mood, weather)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    ClothingItem? selectBest(List<ClothingItem> pool) {
      if (pool.isEmpty) return null;
      pool.sort((a, b) => _scoreItem(b, occasion, mood, weather).compareTo(_scoreItem(a, occasion, mood, weather)));
      return pool.first;
    }

    ClothingItem? top = selectBest(tops);
    ClothingItem? bottom = selectBest(bottoms);
    final dress = selectBest(dresses);
    final shoe = selectBest(shoes);
    final accessory = accessories.isNotEmpty ? accessories[Random().nextInt(accessories.length)] : null;

    if (dress != null && shoe != null && (top == null || bottom == null)) {
      top = dress;
      bottom = null;
    }

    final reasoning = <String>[
      'Occasion: $occasion',
      'Mood: $mood',
      'Weather: $weather',
      'Clean items only: ${cleanItems.length}',
    ];

    final selected = [top, bottom, shoe, accessory].whereType<ClothingItem>().toList();
    final score = selected.isEmpty
        ? 0
        : (selected.map((item) => _scoreItem(item, occasion, mood, weather)).reduce((a, b) => a + b) / selected.length)
            .round()
            .clamp(0, 100);

    if (scored.isNotEmpty) {
      reasoning.add('Top scoring piece: ${scored.first.key.category} (${scored.first.value})');
    }

    if (top == null) {
      reasoning.add('No suitable top found.');
    }
    if (bottom == null) {
      reasoning.add('No suitable bottom found.');
    }
    if (shoe == null) {
      reasoning.add('No suitable shoes found.');
    }

    return OutfitResult(
      top: top,
      bottom: bottom,
      shoes: shoe,
      accessory: accessory,
      score: score,
      reasoning: reasoning,
    );
  }

  List<OutfitResult> generateSuggestionsForEvent({
    required List<ClothingItem> wardrobe,
    required String occasion,
  }) {
    const moods = ['Minimal', 'Clean Drip', 'Street Flex'];
    const weathers = ['Sunny', 'Cold', 'Rainy'];

    final suggestions = <OutfitResult>[];
    for (var i = 0; i < 3; i++) {
      final result = generate(
        wardrobe: wardrobe,
        occasion: occasion,
        mood: moods[i],
        weather: weathers[i],
      );
      if (result.isValid) {
        suggestions.add(result);
      }
    }
    return suggestions;
  }

  int _scoreItem(ClothingItem item, String occasion, String mood, String weather) {
    var score = 40;

    final styles = item.styleTags.map((e) => e.toLowerCase()).toSet();
    final category = item.category.toLowerCase();
    final color = item.color.toLowerCase();

    switch (occasion) {
      case 'Work':
        if (styles.contains('formal') || styles.contains('smart_casual')) score += 20;
        if (styles.contains('streetwear')) score -= 15;
        break;
      case 'Date':
        if (styles.contains('smart_casual') || styles.contains('casual')) score += 20;
        if (styles.contains('sportswear')) score -= 15;
        break;
      case 'Groove':
        if (styles.contains('streetwear') || styles.contains('smart_casual')) score += 20;
        if (styles.contains('formal')) score -= 15;
        break;
      case 'Braai':
        if (styles.contains('casual') || styles.contains('streetwear')) score += 20;
        if (styles.contains('formal')) score -= 20;
        break;
      case 'Event':
        if (styles.contains('formal')) score += 25;
        if (styles.contains('casual') || styles.contains('streetwear')) score -= 15;
        break;
    }

    switch (mood) {
      case 'Minimal':
        if (neutralColors.any(color.contains)) score += 15;
        break;
      case 'Clean Drip':
        if (cleanDripColors.any(color.contains)) score += 15;
        break;
      case 'Street Flex':
        if (styles.contains('streetwear') || category == 'hat' || category == 'shoes') score += 15;
        break;
      case 'Soft Life':
        if (softLifeColors.any(color.contains) || styles.contains('casual')) score += 15;
        break;
    }

    switch (weather) {
      case 'Rainy':
        if (category == 'jacket' || category == 'shoes') score += 10;
        break;
      case 'Cold':
        if (category == 'jacket' || category == 'shirt' || category == 'trousers') score += 10;
        break;
      case 'Hot':
        if (category == 'shorts' || category == 'shirt' || category == 'shoes') score += 10;
        break;
      case 'Sunny':
        if (category == 'shirt' || category == 'accessories') score += 6;
        break;
    }

    return score.clamp(0, 100);
  }

  bool _isTop(String category) =>
      _normalizeCategory(category) == 'shirt' ||
      _normalizeCategory(category) == 'outerwear' ||
      _normalizeCategory(category) == 'dress';

  bool _isBottom(String category) =>
      _normalizeCategory(category) == 'pants' ||
      _normalizeCategory(category) == 'shorts' ||
      _normalizeCategory(category) == 'skirt';

  bool _isShoes(String category) => _normalizeCategory(category) == 'shoes';

  bool _isAccessory(String category) =>
      _normalizeCategory(category) == 'accessory' ||
      _normalizeCategory(category) == 'hat' ||
      _normalizeCategory(category) == 'bag';

  String _normalizeCategory(String category) {
    final value = category.trim().toLowerCase();
    switch (value) {
      case 'top':
      case 'tshirt':
      case 'tee':
      case 'shirt':
        return 'shirt';
      case 'jacket':
      case 'coat':
      case 'outerwear':
        return 'outerwear';
      case 'pants':
      case 'trouser':
      case 'trousers':
      case 'jeans':
      case 'bottom':
        return 'pants';
      case 'shoe':
      case 'shoes':
      case 'sneaker':
      case 'sneakers':
      case 'boot':
      case 'boots':
        return 'shoes';
      case 'accessories':
      case 'accessory':
        return 'accessory';
      default:
        return value;
    }
  }
}
