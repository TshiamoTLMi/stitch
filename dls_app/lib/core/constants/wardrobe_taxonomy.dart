const Map<String, List<String>> categoryTaxonomy = {
  'Tops': [
    'T-shirts',
    'Button-down shirts',
    'Blouses',
    'Tank tops',
    'Crop tops',
    'Knitwear',
    'Sweaters'
  ],
  'Bottoms': ['Jeans', 'Trousers', 'Leggings', 'Skirts', 'Shorts'],
  'Dresses & Jumpsuits': ['Casual dresses', 'Evening dresses', 'Jumpsuits', 'Rompers'],
  'Outerwear': ['Blazers', 'Trench coats', 'Hoodies', 'Puffer jackets', 'Cardigans'],
  'Activewear & Leisure': ['Sports bras', 'Active Leggings', 'Sweatpants', 'Gym tops'],
  'Essentials & Intimates': ['Underwear', 'Socks', 'Hosiery', 'Sleepwear', 'Loungewear'],
  'Accessories': ['Bags', 'Belts', 'Hats', 'Scarves', 'Jewelry'],
  'Footwear': ['Sneakers', 'Boots', 'Heels', 'Flats', 'Sandals', 'Loafers']
};

const List<String> fitOptions = ['Slim', 'Regular', 'Oversized'];

const List<String> styleTagOptions = [
  'formal',
  'casual',
  'streetwear',
  'smart_casual',
  'sportswear',
];

const List<String> seasonOptions = ['All Season', 'Summer', 'Winter', 'Spring', 'Autumn'];

const List<String> statusOptions = ['clean', 'in_wash'];

const List<String> genderOptions = ['Unisex', 'Menswear', 'Womenswear'];

String deriveCategoryType({
  required String parentCategory,
  required String subcategory,
}) {
  switch (parentCategory) {
    case 'Tops':
    case 'Outerwear':
      return 'top';
    case 'Bottoms':
      return 'bottom';
    case 'Dresses & Jumpsuits':
      return 'full';
    case 'Footwear':
      return 'shoes';
    case 'Accessories':
      return 'accessory';
    case 'Activewear & Leisure':
      return subcategory == 'Active Leggings' || subcategory == 'Sweatpants'
          ? 'bottom'
          : 'top';
    case 'Essentials & Intimates':
      return 'accessory';
    default:
      return 'top';
  }
}

/// Functional colour-harmony groups used by the recommendation engine.
///
/// Every supported taxonomy colour maps to exactly ONE explicit group, so no
/// valid colour silently falls back to `neutral`. `teal` is included even
/// though it is not yet in the editor palette, so future colours resolve
/// correctly instead of defaulting.
const Map<String, String> colorGroupMembership = <String, String>{
  // Neutrals
  'black': 'neutral',
  'white': 'neutral',
  'grey': 'neutral',
  'gray': 'neutral',
  'navy': 'neutral',
  'beige': 'neutral',
  'tan': 'neutral',
  'brown': 'neutral',
  'cream': 'neutral',
  // Warm accents
  'red': 'warm',
  'pink': 'warm',
  'yellow': 'warm',
  'orange': 'warm',
  // Cool accents
  'blue': 'cool',
  'green': 'cool',
  'teal': 'cool',
  'purple': 'cool',
  'olive': 'cool',
};

/// The complete set of harmony groups produced by [deriveColorGroup].
const List<String> colorGroupOptions = ['neutral', 'warm', 'cool'];

/// Maps a colour name to its functional harmony group.
///
/// Unknown or empty input resolves to `neutral` as a safe default; every real
/// taxonomy colour is classified explicitly in [colorGroupMembership].
String deriveColorGroup(String colorRaw) {
  final color = colorRaw.trim().toLowerCase();
  if (color.isEmpty) return 'neutral';
  final direct = colorGroupMembership[color];
  if (direct != null) return direct;
  // Tolerate lookups like 'light blue' / 'pastel pink' by keyword match.
  for (final entry in colorGroupMembership.entries) {
    if (color.contains(entry.key)) return entry.value;
  }
  return 'neutral';
}

bool requiresFit(String subcategory) {
  return subcategory == 'Jeans' ||
      subcategory == 'Trousers' ||
      subcategory == 'Blazers';
}
