import '../../models/clothing_item.dart';

/// Dress-code palettes for themed events such as an all-white party.
///
/// A theme is a hard palette filter: only wardrobe items whose colour sits in
/// the palette are considered when building an outfit. Matching is by
/// substring, so `Off-white` or `Charcoal grey` still count as in-palette.
enum OutfitTheme {
  none('No theme', <String>[]),
  allWhite(
    'All-white party',
    <String>['white', 'cream', 'ivory'],
  ),
  blackAndWhite(
    'Black and white party',
    <String>['black', 'white', 'grey', 'gray', 'charcoal', 'cream', 'ivory'],
  );

  const OutfitTheme(this.label, this.palette);

  /// User-facing name shown in the theme picker.
  final String label;

  /// Lower-case colour keywords an item colour must contain.
  final List<String> palette;

  bool get isActive => palette.isNotEmpty;

  /// True when [item] may be used under this theme.
  bool accepts(ClothingItem item) {
    if (!isActive) return true;
    final color = item.color.trim().toLowerCase();
    if (color.isEmpty) return false;
    return palette.any((keyword) => color.contains(keyword));
  }

  /// Parses a stored theme name, falling back to [none] for unknown input.
  static OutfitTheme fromName(String? name) {
    for (final value in OutfitTheme.values) {
      if (value.name == name) return value;
    }
    return OutfitTheme.none;
  }
}
