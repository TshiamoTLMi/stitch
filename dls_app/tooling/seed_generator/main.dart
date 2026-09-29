// DLS Sprint 9 - development seed wardrobe generator.
//
// Purpose: deterministically generate the 300+ item development seed wardrobe
// from the REAL DLS taxonomy (imported from lib/, not duplicated) plus a
// provenance manifest. The application never runs this at runtime; it only
// consumes the generated assets:
//   assets/seed/wardrobe_seed.json
//   assets/seed/dataset_manifest.json
//
// Run from the package root:
//   dart run tooling/seed_generator/main.dart
//
// Image source (CC0, redistribution-safe, verified via the Commons API):
//   Wikimedia Commons - "Europeana Fashion - MoMu - thesaurus drawings"
//   License: CC0 1.0 (Public Domain Dedication), AttributionRequired = false.
//   Artist: David Ring (commissioned by Europeana Fashion, scanned by MoMu).
//
// NOTE: images are referenced by remote CC0 URL for now. Local asset bundling
// is a follow-up step; see dataset_manifest.json.

import 'dart:convert';
import 'dart:io';

import 'package:dls_app/core/constants/wardrobe_taxonomy.dart';
import 'package:uuid/uuid.dart';

/// Stable UUIDv5 namespace for DLS seed identity. Never change this or item
/// ids will drift and duplicates will appear on re-seed.
const String kSeedNamespace = 'a6c1f0a2-1f3b-4c7d-9e21-5b8d0c4a7f10';

const String kCommonsBase =
    'https://commons.wikimedia.org/wiki/Special:FilePath/';

/// Thumbnail width used for the source CC0 image URL.
///
/// MUST be one of Wikimedia's standard thumbnail sizes
/// (`$wgThumbnailSteps`): 20, 40, 60, 120, 250, 330, 500, 960, 1280, 1920, 3840.
/// Non-standard widths are rejected with HTTP 400/429
/// (https://w.wiki/GHai). 500 is used for wardrobe cards.
const int kThumbWidth = 500;

/// Fixed salt so ids/style/colour assignment is deterministic across runs.
const int kSeedSalt = 20260929;

/// Seed rows are owned by a synthetic dev user id, never a real account.
const String kOwnerUserId = 'seed';

/// Target item counts per parent category (DLS taxonomy). Totals 332.
const Map<String, int> kParentTargets = <String, int>{
  'Tops': 72,
  'Bottoms': 56,
  'Outerwear': 40,
  'Dresses & Jumpsuits': 32,
  'Footwear': 48,
  'Accessories': 44,
  'Activewear & Leisure': 24,
  'Essentials & Intimates': 16,
};

/// Local seed image file name -> CC0 MoMu thesaurus source file name.
///
/// Images are downloaded once into `assets/seed/images/` by
/// `tooling/seed_generator/download_seed_images.ps1`; the app then loads them
/// from the asset bundle (local-first, offline-capable).
const Map<String, String> kSeedImageSources = <String, String>{
  'tops-t-shirt.jpg': 'T-shirt (drawing).jpg',
  'tops-blouse.jpg': 'Blouse.jpg',
  'tops-caraco.jpg': 'Caraco.jpg',
  'tops-bodice.jpg': 'Bodice.jpg',
  'tops-sweater.jpg': 'Sweater (clothing).jpg',
  'bottoms-breeches.jpg': 'Breeches.jpg',
  'bottoms-stockings.jpg': 'Stockings (drawing).jpg',
  'bottoms-apron.jpg': 'Apron (protective wear).jpg',
  'bottoms-bermuda.jpg': 'Bermuda (clothing).jpg',
  'dresses-sun-dress.jpg': 'Sun dress.tif',
  'dresses-strapless.jpg': 'Strapless dress.jpg',
  'dresses-smoking-suit.jpg': 'Smoking suit.tif',
  'dresses-baby-suit.jpg': 'Baby suit.tif',
  'outerwear-spencer.jpg': 'Spencer (clothing).jpg',
  'outerwear-anorak.jpg': 'Anorak.jpg',
  'outerwear-barracoat.jpg': 'Barracoat.tif',
  'activewear-swim-suit.jpg': 'Swim suit.jpg',
  'essentials-bathrobe.jpg': 'Bathrobe.jpg',
  'essentials-banyan.jpg': 'Banyan (clothing).jpg',
  'essentials-socks.jpg': 'Socks.jpg',
  'accessories-suitcase.jpg': 'Suitcase (drawing).jpg',
  'accessories-belt.jpg': 'Belt (clothing).jpg',
  'accessories-beret.jpg': 'Beret.jpg',
  'accessories-stole.jpg': 'Stole (outerwear).jpg',
  'accessories-amulet.jpg': 'Amulet (jewelry).jpg',
  'footwear-sport-shoes.jpg': 'Sport shoes.jpg',
  'footwear-apres-ski-boots.jpg': 'Après-ski boots.jpg',
  'footwear-stilettos.jpg': 'Stilettos.jpg',
  'footwear-ballet-flats.jpg': 'Ballet flats.jpg',
  'footwear-slippers.jpg': 'Slippers (drawing).jpg',
  'footwear-bluchers.jpg': 'Bluchers.tif',
};

/// Directory that holds the downloaded CC0 seed images.
const String kSeedImageDir = 'assets/seed/images';

/// DLS subcategory -> LOCAL seed image file name. Some subcategories reuse the
/// closest available CC0 drawing; documented in dataset_manifest.json.
const Map<String, String> kSubcategoryImage = <String, String>{
  // Tops
  'T-shirts': 'tops-t-shirt.jpg',
  'Button-down shirts': 'tops-blouse.jpg',
  'Blouses': 'tops-blouse.jpg',
  'Tank tops': 'tops-caraco.jpg',
  'Crop tops': 'tops-bodice.jpg',
  'Knitwear': 'tops-sweater.jpg',
  'Sweaters': 'tops-sweater.jpg',
  // Bottoms
  'Jeans': 'bottoms-breeches.jpg',
  'Trousers': 'bottoms-breeches.jpg',
  'Leggings': 'bottoms-stockings.jpg',
  'Skirts': 'bottoms-apron.jpg',
  'Shorts': 'bottoms-bermuda.jpg',
  // Dresses & Jumpsuits
  'Casual dresses': 'dresses-sun-dress.jpg',
  'Evening dresses': 'dresses-strapless.jpg',
  'Jumpsuits': 'dresses-smoking-suit.jpg',
  'Rompers': 'dresses-baby-suit.jpg',
  // Outerwear
  'Blazers': 'outerwear-spencer.jpg',
  'Trench coats': 'outerwear-anorak.jpg',
  'Hoodies': 'outerwear-anorak.jpg',
  'Puffer jackets': 'outerwear-barracoat.jpg',
  'Cardigans': 'outerwear-spencer.jpg',
  // Activewear & Leisure
  'Sports bras': 'activewear-swim-suit.jpg',
  'Active Leggings': 'bottoms-stockings.jpg',
  'Sweatpants': 'bottoms-bermuda.jpg',
  'Gym tops': 'tops-caraco.jpg',
  // Essentials & Intimates
  'Underwear': 'tops-bodice.jpg',
  'Socks': 'essentials-socks.jpg',
  'Hosiery': 'bottoms-stockings.jpg',
  'Sleepwear': 'essentials-bathrobe.jpg',
  'Loungewear': 'essentials-banyan.jpg',
  // Accessories
  'Bags': 'accessories-suitcase.jpg',
  'Belts': 'accessories-belt.jpg',
  'Hats': 'accessories-beret.jpg',
  'Scarves': 'accessories-stole.jpg',
  'Jewelry': 'accessories-amulet.jpg',
  // Footwear
  'Sneakers': 'footwear-sport-shoes.jpg',
  'Boots': 'footwear-apres-ski-boots.jpg',
  'Heels': 'footwear-stilettos.jpg',
  'Flats': 'footwear-ballet-flats.jpg',
  'Sandals': 'footwear-slippers.jpg',
  'Loafers': 'footwear-bluchers.jpg',
};

/// Colours used to vary the seed wardrobe. The colour group is derived with the
/// real `deriveColorGroup()` from the taxonomy file (single source of truth).
const List<String> kColors = <String>[
  'black', 'white', 'grey', 'navy', 'brown', 'beige',
  'olive', 'blue', 'green', 'red', 'pink', 'purple',
  'yellow', 'orange', 'cream', 'tan',
];

/// DLS-derived style classification per subcategory. Values are restricted to
/// the existing `styleTagOptions` enum (fixes prior enum drift).
const Map<String, List<String>> kSubcategoryStyles = <String, List<String>>{
  'T-shirts': ['casual', 'streetwear'],
  'Button-down shirts': ['smart_casual', 'formal'],
  'Blouses': ['smart_casual', 'casual'],
  'Tank tops': ['casual', 'smart_casual'],
  'Crop tops': ['streetwear', 'casual'],
  'Knitwear': ['smart_casual', 'casual'],
  'Sweaters': ['casual', 'smart_casual'],
  'Jeans': ['casual', 'streetwear'],
  'Trousers': ['formal', 'smart_casual'],
  'Leggings': ['sportswear', 'casual'],
  'Skirts': ['smart_casual', 'casual'],
  'Shorts': ['casual', 'sportswear'],
  'Casual dresses': ['casual', 'smart_casual'],
  'Evening dresses': ['formal'],
  'Jumpsuits': ['smart_casual', 'streetwear'],
  'Rompers': ['casual'],
  'Blazers': ['formal', 'smart_casual'],
  'Trench coats': ['smart_casual', 'formal'],
  'Hoodies': ['streetwear', 'casual'],
  'Puffer jackets': ['casual', 'sportswear'],
  'Cardigans': ['smart_casual', 'casual'],
  'Sports bras': ['sportswear'],
  'Active Leggings': ['sportswear'],
  'Sweatpants': ['sportswear', 'streetwear'],
  'Gym tops': ['sportswear'],
  'Underwear': ['casual'],
  'Socks': ['casual', 'formal'],
  'Hosiery': ['formal'],
  'Sleepwear': ['casual'],
  'Loungewear': ['casual'],
  'Bags': ['smart_casual', 'streetwear'],
  'Belts': ['formal', 'smart_casual'],
  'Hats': ['casual', 'streetwear'],
  'Scarves': ['smart_casual', 'casual'],
  'Jewelry': ['formal', 'smart_casual'],
  'Sneakers': ['casual', 'streetwear', 'sportswear'],
  'Boots': ['casual', 'streetwear'],
  'Heels': ['formal'],
  'Flats': ['casual', 'smart_casual'],
  'Sandals': ['casual'],
  'Loafers': ['formal', 'smart_casual'],
};

/// Season assignment per subcategory (values from `seasonOptions`).
const Map<String, List<String>> kSubcategorySeasons = <String, List<String>>{
  'Sweaters': ['Winter', 'Autumn'],
  'Knitwear': ['Winter', 'Autumn'],
  'Cardigans': ['Autumn', 'Spring', 'All Season'],
  'Puffer jackets': ['Winter'],
  'Trench coats': ['Autumn', 'Spring'],
  'Boots': ['Winter', 'Autumn'],
  'Sandals': ['Summer'],
  'Shorts': ['Summer'],
  'Tank tops': ['Summer'],
  'Crop tops': ['Summer', 'Spring'],
  'Casual dresses': ['Summer', 'Spring', 'All Season'],
  'Evening dresses': ['All Season'],
  'Rompers': ['Summer'],
  'Sports bras': ['All Season'],
  'Active Leggings': ['All Season'],
  'Heels': ['All Season'],
  'Scarves': ['Winter', 'Autumn'],
};

/// Subcategories predominantly for a specific gender; all others are Unisex.
const Map<String, String> kSubcategoryGender = <String, String>{
  'Sports bras': 'Womenswear',
  'Heels': 'Womenswear',
  'Blouses': 'Womenswear',
  'Crop tops': 'Womenswear',
  'Evening dresses': 'Womenswear',
  'Casual dresses': 'Womenswear',
  'Skirts': 'Womenswear',
  'Hosiery': 'Womenswear',
  'Rompers': 'Womenswear',
  'Jumpsuits': 'Womenswear',
};

// --- Deterministic pseudo-random helpers -------------------------------------

int _hash(int index, int salt) {
  var x = (index * 1103515245 + salt) & 0x7fffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
  x = (x ^ (x >> 16)) & 0x7fffffff;
  return x;
}

int _pick(int index, int salt, int max) => _hash(index, salt) % max;

String _thumbUrl(String filename) =>
    '$kCommonsBase${Uri.encodeComponent(filename)}?width=$kThumbWidth';

// --- Generation --------------------------------------------------------------

Map<String, dynamic> _buildItem({
  required String parentCategory,
  required String subcategory,
  required int globalIndex,
}) {
  final color = kColors[_pick(globalIndex, 11, kColors.length)];
  final styles = kSubcategoryStyles[subcategory] ?? const <String>['casual'];
  final seasons = kSubcategorySeasons[subcategory] ?? const <String>['All Season'];
  final season = seasons[_pick(globalIndex, 23, seasons.length)];
  final gender = kSubcategoryGender[subcategory] ?? 'Unisex';
  final imageFile = kSubcategoryImage[subcategory] ?? 'tops-t-shirt.jpg';
  final sourceFile =
      kSeedImageSources[imageFile] ?? 'T-shirt (drawing).jpg';
  final fit = requiresFit(subcategory)
      ? fitOptions[_pick(globalIndex, 37, fitOptions.length)]
      : null;
  final id = const Uuid().v5(
    kSeedNamespace,
    'DLS|$parentCategory|$subcategory|$globalIndex',
  );

  return <String, dynamic>{
    'id': id,
    'parentCategory': parentCategory,
    'subcategory': subcategory,
    'categoryType': deriveCategoryType(
      parentCategory: parentCategory,
      subcategory: subcategory,
    ),
    if (fit != null) 'fit': fit,
    'color': color,
    'colorGroup': deriveColorGroup(color),
    'styleTags': styles,
    'season': season,
    'status': 'clean',
    'gender': gender,
    'imageUrl': _thumbUrl(sourceFile),
    'localImagePath': '$kSeedImageDir/$imageFile',
    'userId': kOwnerUserId,
  };
}

// --- Entry point -------------------------------------------------------------

void main() {
  final items = <Map<String, dynamic>>[];
  var globalIndex = 0;

  kParentTargets.forEach((parent, target) {
    final subs = categoryTaxonomy[parent];
    if (subs == null || subs.isEmpty) {
      throw StateError('Taxonomy is missing parent category "$parent".');
    }
    final base = target ~/ subs.length;
    final remainder = target % subs.length;
    for (var s = 0; s < subs.length; s++) {
      final count = base + (s < remainder ? 1 : 0);
      for (var i = 0; i < count; i++) {
        items.add(_buildItem(
          parentCategory: parent,
          subcategory: subs[s],
          globalIndex: globalIndex,
        ));
        globalIndex++;
      }
    }
  });

  // --- Validation (fail loudly rather than emit a bad dataset) ---
  if (items.length < 300) {
    throw StateError('Seed dataset has ${items.length} items; 300+ required.');
  }
  final ids = items.map((item) => item['id'] as String).toSet();
  if (ids.length != items.length) {
    throw StateError('Duplicate seed ids detected (${items.length - ids.length}).');
  }
  for (final item in items) {
    final image = item['imageUrl'] as String;
    if (!image.startsWith(kCommonsBase)) {
      throw StateError('Non-CC0 image reference: $image');
    }
    final localImage = item['localImagePath'] as String;
    if (!localImage.startsWith('$kSeedImageDir/')) {
      throw StateError('Seed item missing a local asset path: $localImage');
    }
    if (!kColors.contains(item['color'])) {
      throw StateError('Unknown colour: ${item['color']}');
    }
    for (final tag in item['styleTags'] as List<String>) {
      if (!styleTagOptions.contains(tag)) {
        throw StateError('Style tag outside enum: $tag');
      }
    }
    if (!seasonOptions.contains(item['season'])) {
      throw StateError('Season outside enum: ${item['season']}');
    }
  }

  final counts = <String, int>{};
  for (final item in items) {
    final parent = item['parentCategory'] as String;
    counts[parent] = (counts[parent] ?? 0) + 1;
  }
  final imageFiles = kSubcategoryImage.values.toSet();
  final missingImages = imageFiles
      .where((file) => !File('$kSeedImageDir/$file').existsSync())
      .toList()
    ..sort();

  // Emits the download plan consumed by download_seed_images.ps1.
  File('tooling/seed_generator/seed_image_downloads.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'base': kCommonsBase,
      'thumbWidth': kThumbWidth,
      'images': kSeedImageSources.map(
        (local, source) => MapEntry(local, _thumbUrl(source)),
      ),
    }),
  );

  final seedFile = File('assets/seed/wardrobe_seed.json');
  seedFile.parent.createSync(recursive: true);
  seedFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'version': 1,
      'namespace': kSeedNamespace,
      'itemCount': items.length,
      'items': items,
    }),
  );

  final manifest = <String, dynamic>{
    'sourceDataset':
        'Europeana Fashion - MoMu - Thesaurus drawings (David Ring)',
    'sourceUrl':
        'https://commons.wikimedia.org/wiki/Category:Europeana_Fashion_-_MoMu_-_thesaurus_drawings',
    'license': 'CC0 1.0 (Creative Commons Zero, Public Domain Dedication)',
    'licenseUrl': 'https://creativecommons.org/publicdomain/zero/1.0/',
    'attributionRequired': false,
    'attribution':
        'Drawings by David Ring, commissioned by Europeana Fashion, scanned by MoMu. CC0 - credit appreciated but not required.',
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'generator': 'tooling/seed_generator/main.dart',
    'itemCount': items.length,
    'uniqueImageCount': imageFiles.length,
    'distributionByParentCategory': counts,
    'imageDelivery':
        'local bundled asset under $kSeedImageDir (source CC0 URL retained in imageUrl)',
    'imageBundlingStatus':
        'bundled locally; downloaded once via tooling/seed_generator/download_seed_images.ps1',
    'uniqueLocalImageCount': imageFiles.length,
    'missingLocalImages': missingImages,
    'transformations': <String>[
      'category normalization (DLS taxonomy import, not duplicated)',
      'colour normalization + colourGroup via deriveColorGroup()',
      'DLS-derived style classification (restricted to styleTagOptions)',
      'season + gender assignment',
      'stable UUIDv5 identity (namespace $kSeedNamespace)',
      'CC0 image mapping per subcategory',
    ],
    'notes': <String>[
      'No third-party product imagery is bundled or redistributed.',
      'Style labels are DLS-derived, not sourced from the dataset.',
      'Some subcategories reuse the closest available CC0 drawing.',
      'This dataset is a development/test fixture and is NOT seeded into production users.',
    ],
  };
  File('assets/seed/dataset_manifest.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );

  stdout.writeln('Seed items: ${items.length}');
  stdout.writeln('Unique ids: ${ids.length}');
  stdout.writeln('Unique local images: ${imageFiles.length}');
  stdout.writeln('Missing local images: ${missingImages.length}');
  if (missingImages.isNotEmpty) {
    stdout.writeln('  (run download_seed_images.ps1) ${missingImages.join(', ')}');
  }
  counts.forEach((parent, count) => stdout.writeln('  $parent: $count'));
  stdout.writeln('Wrote assets/seed/wardrobe_seed.json');
  stdout.writeln('Wrote assets/seed/dataset_manifest.json');
}



