import 'dart:math';

import '../models/clothing_item.dart';
import '../models/outfit_result.dart';

class OutfitReadiness {
  const OutfitReadiness({
    required this.canGenerate,
    required this.missingRequirements,
  });

  final bool canGenerate;
  final List<String> missingRequirements;

  String get userFriendlyMessage {
    if (canGenerate) {
      return 'Your wardrobe has enough clean pieces. Ready to generate.';
    }

    if (missingRequirements.isEmpty) {
      return 'We need a few more clean items before we can build a full fit.';
    }

    return 'Add clean ${missingRequirements.join(' and ')} to generate a complete outfit.';
  }
}

class OutfitBotService {
  static const neutralColors = {'black', 'white', 'grey', 'beige'};
  static const cleanDripColors = {'white', 'cream', 'pastel', 'light blue'};
  static const softLifeColors = {'olive', 'brown', 'beige', 'sand', 'earth'};

  OutfitReadiness checkReadiness(List<ClothingItem> wardrobe) {
    final cleanItems = wardrobe.where((item) => item.isClean).toList();
    if (cleanItems.isEmpty) {
      return const OutfitReadiness(
        canGenerate: false,
        missingRequirements: ['tops', 'bottoms (or a dress)', 'shoes'],
      );
    }

    final hasTop = cleanItems.any((item) => _isTop(item.categoryType, item.category));
    final hasBottom = cleanItems.any((item) => _isBottom(item.categoryType, item.category));
    final hasDress = cleanItems.any((item) => _isFull(item.categoryType, item.category));
    final hasShoes = cleanItems.any((item) => _isShoes(item.categoryType, item.category));

    final missing = <String>[];
    final hasBodyBase = (hasTop && hasBottom) || hasDress;
    if (!hasBodyBase) {
      if (!hasTop && !hasDress) {
        missing.add('tops or dresses');
      }
      if (!hasBottom && !hasDress) {
        missing.add('bottoms or dresses');
      }
    }
    if (!hasShoes) {
      missing.add('shoes');
    }

    return OutfitReadiness(
      canGenerate: missing.isEmpty,
      missingRequirements: missing,
    );
  }

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

    final tops = cleanItems.where((item) => _isTop(item.categoryType, item.category)).toList();
    final bottoms = cleanItems.where((item) => _isBottom(item.categoryType, item.category)).toList();
    final dresses = cleanItems.where((item) => _isFull(item.categoryType, item.category)).toList();
    final shoes = cleanItems.where((item) => _isShoes(item.categoryType, item.category)).toList();
    final accessories = cleanItems
      .where((item) => _isAccessory(item.categoryType, item.category))
      .toList();

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
      reasoning.add('Top scoring piece: ${scored.first.key.subcategory} (${scored.first.value})');
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
    final category = item.subcategory.toLowerCase();
    final categoryType = item.categoryType.toLowerCase();
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
        if (styles.contains('streetwear') || category.contains('hat') || categoryType == 'shoes') {
          score += 15;
        }
        break;
      case 'Soft Life':
        if (softLifeColors.any(color.contains) || styles.contains('casual')) score += 15;
        break;
    }

    switch (weather) {
      case 'Rainy':
        if (category.contains('jacket') || categoryType == 'shoes') score += 10;
        break;
      case 'Cold':
        if (category.contains('jacket') || categoryType == 'top' || category.contains('trouser')) {
          score += 10;
        }
        break;
      case 'Hot':
        if (category.contains('shorts') || categoryType == 'top' || categoryType == 'shoes') {
          score += 10;
        }
        break;
      case 'Sunny':
        if (categoryType == 'top' || categoryType == 'accessory') score += 6;
        break;
    }

    return score.clamp(0, 100);
  }

  bool _isTop(String categoryType, String fallbackCategory) {
    if (categoryType == 'top') return true;
    return _normalizeCategory(fallbackCategory) == 'shirt' ||
        _normalizeCategory(fallbackCategory) == 'outerwear';
  }

  bool _isBottom(String categoryType, String fallbackCategory) {
    if (categoryType == 'bottom') return true;
    return _normalizeCategory(fallbackCategory) == 'pants' ||
        _normalizeCategory(fallbackCategory) == 'shorts' ||
        _normalizeCategory(fallbackCategory) == 'skirt';
  }

  bool _isFull(String categoryType, String fallbackCategory) {
    if (categoryType == 'full') return true;
    return _normalizeCategory(fallbackCategory) == 'dress';
  }

  bool _isShoes(String categoryType, String fallbackCategory) {
    if (categoryType == 'shoes') return true;
    return _normalizeCategory(fallbackCategory) == 'shoes';
  }

  bool _isAccessory(String categoryType, String fallbackCategory) {
    if (categoryType == 'accessory') return true;
    return _normalizeCategory(fallbackCategory) == 'accessory' ||
        _normalizeCategory(fallbackCategory) == 'hat' ||
        _normalizeCategory(fallbackCategory) == 'bag';
  }

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
