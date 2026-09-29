import '../models/clothing_item.dart';

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

/// Pre-flight validation for the wardrobe.
///
/// Sprint 9: this service is a **readiness check only**. All generation and
/// scoring live exclusively in `AffinityEngine` / `CandidateGenerator`:
///   * Outfit Generator -> `lib/views/home/outfit_generator_page.dart`
///   * Event Planner    -> `EventOutfitSuggester`
///
/// The legacy `generate()`, `generateSuggestionsForEvent()` and `_scoreItem()`
/// methods have been deleted, so the app contains no second scoring path.
class OutfitBotService {
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
