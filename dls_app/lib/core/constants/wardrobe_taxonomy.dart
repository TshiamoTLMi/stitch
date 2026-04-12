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

String deriveColorGroup(String colorRaw) {
  final color = colorRaw.trim().toLowerCase();
  if (const {'black', 'white', 'grey'}.contains(color)) return 'neutral';
  if (const {'navy', 'brown'}.contains(color)) return 'dark';
  if (color == 'beige' || color.contains('pastel')) return 'light';
  if (const {'red', 'yellow'}.contains(color)) return 'bright';
  return 'neutral';
}

bool requiresFit(String subcategory) {
  return subcategory == 'Jeans' ||
      subcategory == 'Trousers' ||
      subcategory == 'Blazers';
}
