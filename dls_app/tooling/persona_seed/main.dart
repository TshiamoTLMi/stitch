// Offline generator for the four test personas (assets/seed/personas.json).
//
// Derives wardrobe attributes from the local training metadata
// (fashion-dataset/styles.csv). Run it only inside the offline, read-only
// `training-data-test` container (see docker/docker-compose.yml):
//
//   docker compose -f docker/docker-compose.yml --profile training-data \
//     run --rm training-data-test bash -c "dart run tooling/persona_seed/main.dart"
//
// Only derived attributes are written: category, colour, style tags, season,
// gender, and a CC0 image reference. Product names, dataset ids, source image
// paths and photos are never written, so the committed JSON contains no
// training-set content.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dls_app/core/constants/wardrobe_taxonomy.dart';
import '../seed_generator/main.dart'
    show
        kCommonsBase,
        kSeedImageDir,
        kSeedImageSources,
        kSubcategoryImage,
        kThumbWidth;

const int kPersonaRandomSeed = 20261010;
const String kPersonasOutput = 'assets/seed/personas.json';
const int kMinUnisexPerPersona = 8;
const int kMinItemsPerPersona = 120;
const int kOutfitsPerPersona = 6;

/// Training `gender` values used by the personas. `Boys`/`Girls` are skipped.
const Set<String> kTrainingGenders = <String>{'Men', 'Women', 'Unisex'};

/// Training `usage` values we map. `NA`, `Ethnic` and empty values are skipped.
const Map<String, String> kUsageStyle = <String, String>{
  'Casual': 'casual',
  'Sports': 'sportswear',
  'Formal': 'formal',
  'Smart Casual': 'smart_casual',
  'Party': 'smart_casual',
  'Travel': 'casual',
};

/// Gender-neutral silhouettes. These become `Unisex` whatever source label
/// they carry, because the training set labels very few apparel rows Unisex.
const Set<String> kNeutralSubcategories = <String>{
  'T-shirts',
  'Hoodies',
  'Sweatpants',
  'Shorts',
  'Sneakers',
  'Sandals',
  'Socks',
  'Hats',
  'Belts',
};

/// Subcategories that get a `streetwear` tag when the source usage is Casual.
const Set<String> kStreetSubcategories = <String>{
  'T-shirts',
  'Hoodies',
  'Sweatpants',
  'Sneakers',
  'Hats',
};

/// Training `articleType` -> DLS subcategory.
const Map<String, String> kArticleSubcategory = <String, String>{
  'Tshirts': 'T-shirts',
  'Shirts': 'Button-down shirts',
  'Tops': 'Blouses',
  'Camisoles': 'Tank tops',
  'Sweaters': 'Sweaters',
  'Sweatshirts': 'Hoodies',
  'Blazers': 'Blazers',
  'Jackets': 'Trench coats',
  'Rain Jacket': 'Trench coats',
  'Shrug': 'Cardigans',
  'Jeans': 'Jeans',
  'Trousers': 'Trousers',
  'Leggings': 'Leggings',
  'Skirts': 'Skirts',
  'Shorts': 'Shorts',
  'Dresses': 'Casual dresses',
  'Jumpsuit': 'Jumpsuits',
  'Track Pants': 'Sweatpants',
  'Lounge Pants': 'Loungewear',
  'Lounge Shorts': 'Loungewear',
  'Lounge Tshirts': 'Loungewear',
  'Night suits': 'Sleepwear',
  'Casual Shoes': 'Sneakers',
  'Sports Shoes': 'Sneakers',
  'Formal Shoes': 'Loafers',
  'Heels': 'Heels',
  'Flats': 'Flats',
  'Sandals': 'Sandals',
  'Sports Sandals': 'Sandals',
  'Flip Flops': 'Sandals',
  'Handbags': 'Bags',
  'Backpacks': 'Bags',
  'Clutches': 'Bags',
  'Messenger Bag': 'Bags',
  'Belts': 'Belts',
  'Caps': 'Hats',
  'Hats': 'Hats',
  'Scarves': 'Scarves',
  'Stoles': 'Scarves',
  'Watches': 'Jewelry',
  'Jewellery': 'Jewelry',
  'Socks': 'Socks',
};

/// Training `baseColour` -> taxonomy colour. Unmapped colours are skipped.
const Map<String, String> kColourMap = <String, String>{
  'Black': 'black',
  'White': 'white',
  'Blue': 'blue',
  'Navy Blue': 'navy',
  'Turquoise Blue': 'blue',
  'Teal': 'blue',
  'Brown': 'brown',
  'Coffee Brown': 'brown',
  'Bronze': 'brown',
  'Grey': 'grey',
  'Grey Melange': 'grey',
  'Silver': 'grey',
  'Steel': 'grey',
  'Charcoal': 'grey',
  'Metallic': 'grey',
  'Red': 'red',
  'Maroon': 'red',
  'Burgundy': 'red',
  'Rust': 'orange',
  'Orange': 'orange',
  'Peach': 'orange',
  'Copper': 'orange',
  'Pink': 'pink',
  'Magenta': 'pink',
  'Rose': 'pink',
  'Purple': 'purple',
  'Lavender': 'purple',
  'Mauve': 'purple',
  'Yellow': 'yellow',
  'Mustard': 'yellow',
  'Gold': 'tan',
  'Beige': 'beige',
  'Skin': 'beige',
  'Cream': 'cream',
  'Off White': 'cream',
  'Khaki': 'tan',
  'Tan': 'tan',
  'Olive': 'olive',
  'Green': 'green',
};

class PersonaSlot {
  const PersonaSlot(this.subcategory, this.count);

  final String subcategory;
  final int count;
}

class PersonaSpec {
  const PersonaSpec({
    required this.id,
    required this.displayName,
    required this.trainingGender,
    required this.gender,
    required this.usages,
    required this.stylePreferences,
    required this.occasions,
    required this.eventTitles,
    required this.unisexSlots,
    required this.genderedSlots,
  });

  final String id;
  final String displayName;
  final String trainingGender;
  final String gender;
  final Set<String> usages;
  final List<String> stylePreferences;
  final List<String> occasions;
  final List<String> eventTitles;
  final List<PersonaSlot> unisexSlots;
  final List<PersonaSlot> genderedSlots;
}

const Set<String> _casualUsages = <String>{'Casual', 'Sports', 'Travel'};
const Set<String> _smartUsages = <String>{'Formal', 'Smart Casual', 'Party'};

const List<PersonaSpec> kPersonaSpecs = <PersonaSpec>[
  PersonaSpec(
    id: 'man_street',
    displayName: 'Man - Street & Casual',
    trainingGender: 'Men',
    gender: 'Menswear',
    usages: _casualUsages,
    stylePreferences: <String>['casual', 'streetwear', 'sportswear'],
    occasions: <String>['Groove', 'Braai', 'Date'],
    eventTitles: <String>['Friday Groove', 'Weekend Braai', 'Coffee Meetup'],
    unisexSlots: <PersonaSlot>[
      PersonaSlot('T-shirts', 2),
      PersonaSlot('Hoodies', 1),
      PersonaSlot('Sneakers', 2),
      PersonaSlot('Sandals', 1),
      PersonaSlot('Bags', 1),
      PersonaSlot('Hats', 1),
      PersonaSlot('Socks', 1),
      PersonaSlot('Belts', 1),
    ],
    genderedSlots: <PersonaSlot>[
      PersonaSlot('Button-down shirts', 2),
      PersonaSlot('Jeans', 2),
      PersonaSlot('Trousers', 1),
      PersonaSlot('Trench coats', 1),
      PersonaSlot('Sweaters', 1),
      PersonaSlot('Loafers', 1),
      PersonaSlot('Jewelry', 1),
    ],
  ),
  PersonaSpec(
    id: 'man_smart',
    displayName: 'Man - Smart & Formal',
    trainingGender: 'Men',
    gender: 'Menswear',
    usages: _smartUsages,
    stylePreferences: <String>['formal', 'smart_casual'],
    occasions: <String>['Work', 'Date', 'Event'],
    eventTitles: <String>['Client Meeting', 'Dinner Date', 'Wedding Reception'],
    unisexSlots: <PersonaSlot>[
      PersonaSlot('T-shirts', 2),
      PersonaSlot('Sneakers', 2),
      PersonaSlot('Socks', 1),
      PersonaSlot('Belts', 1),
      PersonaSlot('Bags', 1),
      PersonaSlot('Jewelry', 1),
    ],
    genderedSlots: <PersonaSlot>[
      PersonaSlot('Button-down shirts', 3),
      PersonaSlot('Trousers', 2),
      PersonaSlot('Jeans', 1),
      PersonaSlot('Blazers', 1),
      PersonaSlot('Loafers', 2),
      PersonaSlot('Sweaters', 1),
      PersonaSlot('Trench coats', 1),
    ],
  ),
  PersonaSpec(
    id: 'woman_casual',
    displayName: 'Woman - Casual & Active',
    trainingGender: 'Women',
    gender: 'Womenswear',
    usages: _casualUsages,
    stylePreferences: <String>['casual', 'streetwear', 'sportswear'],
    occasions: <String>['Groove', 'Braai', 'Date'],
    eventTitles: <String>['Brunch Date', 'Weekend Braai', 'Friday Groove'],
    unisexSlots: <PersonaSlot>[
      PersonaSlot('T-shirts', 2),
      PersonaSlot('Hoodies', 1),
      PersonaSlot('Sneakers', 2),
      PersonaSlot('Shorts', 1),
      PersonaSlot('Socks', 1),
      PersonaSlot('Hats', 1),
    ],
    genderedSlots: <PersonaSlot>[
      PersonaSlot('Blouses', 2),
      PersonaSlot('Tank tops', 1),
      PersonaSlot('Sweaters', 1),
      PersonaSlot('Jeans', 2),
      PersonaSlot('Skirts', 1),
      PersonaSlot('Leggings', 1),
      PersonaSlot('Casual dresses', 2),
      PersonaSlot('Flats', 1),
      PersonaSlot('Loungewear', 1),
      PersonaSlot('Bags', 1),
    ],
  ),
  PersonaSpec(
    id: 'woman_smart',
    displayName: 'Woman - Smart & Formal',
    trainingGender: 'Women',
    gender: 'Womenswear',
    usages: _smartUsages,
    stylePreferences: <String>['formal', 'smart_casual'],
    occasions: <String>['Work', 'Event', 'Date'],
    eventTitles: <String>['Board Meeting', 'Wedding Guest', 'Evening Date'],
    unisexSlots: <PersonaSlot>[
      PersonaSlot('T-shirts', 2),
      PersonaSlot('Sneakers', 2),
      PersonaSlot('Belts', 1),
      PersonaSlot('Socks', 1),
      PersonaSlot('Sandals', 1),
      PersonaSlot('Bags', 1),
    ],
    genderedSlots: <PersonaSlot>[
      PersonaSlot('Blouses', 3),
      PersonaSlot('Trousers', 2),
      PersonaSlot('Skirts', 2),
      PersonaSlot('Casual dresses', 2),
      PersonaSlot('Jumpsuits', 1),
      PersonaSlot('Heels', 2),
      PersonaSlot('Flats', 1),
      PersonaSlot('Blazers', 1),
      PersonaSlot('Jewelry', 2),
      PersonaSlot('Bags', 1),
    ],
  ),
];

class _Row {
  _Row({
    required this.trainingGender,
    required this.subcategory,
    required this.colour,
    required this.season,
    required this.usage,
  });

  final String trainingGender;
  final String subcategory;
  final String colour;
  final String season;
  final String usage;
}

class _Pick {
  const _Pick(this.row, this.unisex);

  final _Row row;
  final bool unisex;
}

void main() {
  final root = Platform.environment['TRAINING_DATA_DIR'] ?? 'training_data';
  final csv = File('$root/fashion-dataset/styles.csv');
  if (!csv.existsSync()) {
    throw StateError(
      'styles.csv not found at ${csv.path}. Set TRAINING_DATA_DIR to the '
      'folder that contains fashion-dataset/.',
    );
  }

  final rows = _loadRows(csv);
  stdout.writeln('Loaded ${rows.length} mappable training rows.');

  final personas = <Map<String, dynamic>>[];
  for (var i = 0; i < kPersonaSpecs.length; i++) {
    personas.add(_buildPersona(kPersonaSpecs[i], i, rows));
  }

  final document = <String, dynamic>{
    'version': 1,
    'generator': 'tooling/persona_seed/main.dart',
    'source':
        'Derived attributes only (category, colour, style, season, gender) '
        'from local training metadata. No product names, dataset ids, source '
        'image paths or photos are included.',
    'unisexRule':
        'Training gender Unisex, plus gender-neutral silhouettes '
        '(${kNeutralSubcategories.join(', ')}) from any gender label.',
    'personas': personas,
  };
  final encoder = const JsonEncoder.withIndent('  ');
  final output = File(kPersonasOutput);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('${encoder.convert(document)}\n');
  stdout.writeln('Wrote ${output.path} with ${personas.length} personas.');
}

List<_Row> _loadRows(File csv) {
  final lines = csv.readAsLinesSync();
  final header = _splitCsv(lines.first);
  int col(String name) {
    final index = header.indexOf(name);
    if (index < 0) throw StateError('styles.csv is missing column "$name".');
    return index;
  }

  final iGender = col('gender');
  final iArticle = col('articleType');
  final iColour = col('baseColour');
  final iSeason = col('season');
  final iUsage = col('usage');

  final rows = <_Row>[];
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final fields = _splitCsv(line);
    if (fields.length != header.length) continue;

    final trainingGender = fields[iGender];
    if (!kTrainingGenders.contains(trainingGender)) continue;

    final subcategory = kArticleSubcategory[fields[iArticle]];
    if (subcategory == null) continue;

    final colour = kColourMap[fields[iColour]];
    if (colour == null) continue;

    final usage = fields[iUsage].trim();
    if (!kUsageStyle.containsKey(usage)) continue;

    final rawSeason = fields[iSeason].trim();
    final season = switch (rawSeason) {
      '' => 'All Season',
      'Fall' => 'Autumn',
      _ => rawSeason,
    };
    if (!seasonOptions.contains(season)) continue;

    rows.add(_Row(
      trainingGender: trainingGender,
      subcategory: subcategory,
      colour: colour,
      season: season,
      usage: usage,
    ));
  }
  return rows;
}

/// Minimal RFC 4180 field splitter (handles quoted fields and "" escapes).
List<String> _splitCsv(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (c == ',' && !inQuotes) {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(c);
    }
  }
  fields.add(buffer.toString());
  return fields;
}

String _parentOf(String subcategory) {
  for (final entry in categoryTaxonomy.entries) {
    if (entry.value.contains(subcategory)) return entry.key;
  }
  throw StateError('Subcategory not in taxonomy: $subcategory');
}

Map<String, dynamic> _buildPersona(
  PersonaSpec spec,
  int index,
  List<_Row> rows,
) {
  final rng = Random(kPersonaRandomSeed + index);
  final used = <_Row>{};
  final picks = <_Pick>[];

  /// Adds up to `slot.count` unused rows and returns how many were added.
  int fill(PersonaSlot slot, {required bool unisex, required bool allowShortfall}) {
    bool eligible(_Row row) {
      if (used.contains(row) || row.subcategory != slot.subcategory) {
        return false;
      }
      if (unisex) {
        return row.trainingGender == 'Unisex' ||
            kNeutralSubcategories.contains(row.subcategory);
      }
      return row.trainingGender == spec.trainingGender &&
          !kNeutralSubcategories.contains(row.subcategory);
    }

    var pool = rows
        .where((row) => eligible(row) && spec.usages.contains(row.usage))
        .toList();
    if (pool.length < slot.count) {
      pool = rows.where(eligible).toList();
      stdout.writeln(
        '  relaxed usage filter: ${spec.id} ${slot.subcategory} '
        '(${unisex ? 'unisex' : 'gendered'})',
      );
    }
    if (pool.length < slot.count && !allowShortfall) {
      throw StateError(
        '${spec.id}: only ${pool.length} of ${slot.count} rows for '
        '${slot.subcategory}.',
      );
    }
    pool.shuffle(rng);
    final taken = pool.take(slot.count).toList();
    for (final row in taken) {
      used.add(row);
      picks.add(_Pick(row, unisex));
    }
    return taken.length;
  }

  final allSlots = <(PersonaSlot, bool)>[
    for (final slot in spec.unisexSlots) (slot, true),
    for (final slot in spec.genderedSlots) (slot, false),
  ];
  for (final (slot, unisex) in allSlots) {
    fill(slot, unisex: unisex, allowShortfall: false);
  }

  // Top up to the closet minimum, cycling so the slot mix stays proportional.
  final weighted = <(PersonaSlot, bool)>[
    for (final (slot, unisex) in allSlots)
      for (var n = 0; n < slot.count; n++)
        (PersonaSlot(slot.subcategory, 1), unisex),
  ];
  var cursor = 0;
  var misses = 0;
  while (picks.length < kMinItemsPerPersona) {
    final (slot, unisex) = weighted[cursor % weighted.length];
    cursor++;
    if (fill(slot, unisex: unisex, allowShortfall: true) > 0) {
      misses = 0;
    } else if (++misses > weighted.length) {
      throw StateError(
        '${spec.id}: only ${picks.length} items available; '
        '$kMinItemsPerPersona required.',
      );
    }
  }

  final items = <Map<String, dynamic>>[];
  for (var i = 0; i < picks.length; i++) {
    final pick = picks[i];
    final subcategory = pick.row.subcategory;
    final parent = _parentOf(subcategory);
    final imageFile = kSubcategoryImage[subcategory];
    if (imageFile == null) {
      throw StateError('No CC0 image mapped for $subcategory.');
    }
    final sourceFile = kSeedImageSources[imageFile];
    if (sourceFile == null) {
      throw StateError('No CC0 source for image $imageFile.');
    }
    final fit = requiresFit(subcategory)
        ? fitOptions[rng.nextInt(fitOptions.length)]
        : null;
    final status = rng.nextInt(6) == 0 ? 'in_wash' : 'clean';
    final colour = pick.row.colour;

    items.add(<String, dynamic>{
      'localId': '${spec.id}-${(i + 1).toString().padLeft(3, '0')}',
      'parentCategory': parent,
      'subcategory': subcategory,
      'categoryType':
          deriveCategoryType(parentCategory: parent, subcategory: subcategory),
      if (fit != null) 'fit': fit,
      'color': colour,
      'colorGroup': deriveColorGroup(colour),
      'styleTags': <String>{
        if (kUsageStyle[pick.row.usage] != null) kUsageStyle[pick.row.usage]!,
        if (pick.row.usage == 'Casual' &&
            kStreetSubcategories.contains(subcategory))
          'streetwear',
      }.toList(),
      'season': pick.row.season,
      'status': status,
      'gender': pick.unisex ? 'Unisex' : spec.gender,
      'imageUrl':
          '$kCommonsBase${Uri.encodeComponent(sourceFile)}?width=$kThumbWidth',
      'localImagePath': '$kSeedImageDir/$imageFile',
    });
  }

  _validateItems(spec, items);
  if (items.length < kMinItemsPerPersona) {
    throw StateError(
      '${spec.id}: ${items.length} items; at least $kMinItemsPerPersona required.',
    );
  }

  final unisexCount = items.where((item) => item['gender'] == 'Unisex').length;
  if (unisexCount < kMinUnisexPerPersona) {
    throw StateError(
      '${spec.id}: $unisexCount unisex items; at least $kMinUnisexPerPersona required.',
    );
  }

  final outfits = _buildOutfits(spec, items, rng);
  final events = <Map<String, dynamic>>[];
  const offsets = <int>[2, 5, 9];
  for (var i = 0; i < spec.eventTitles.length; i++) {
    final outfit = outfits[i % outfits.length];
    events.add(<String, dynamic>{
      'name': spec.eventTitles[i],
      'occasion': spec.occasions[i % spec.occasions.length],
      'daysFromNow': offsets[i],
      'recommendedOutfits': <String>[
        'Score ${outfit['score']}: ${outfit['summary']}',
      ],
    });
  }

  stdout.writeln(
    '${spec.id}: ${items.length} items, $unisexCount unisex, '
    '${outfits.length} outfits, ${events.length} events',
  );

  return <String, dynamic>{
    'id': spec.id,
    'displayName': spec.displayName,
    'gender': spec.gender,
    'stylePreferences': spec.stylePreferences,
    'items': items,
    'outfits': outfits,
    'events': events,
  };
}

void _validateItems(PersonaSpec spec, List<Map<String, dynamic>> items) {
  for (final item in items) {
    final subcategory = item['subcategory'] as String;
    final parent = item['parentCategory'] as String;
    if (!(categoryTaxonomy[parent]?.contains(subcategory) ?? false)) {
      throw StateError('${spec.id}: $subcategory not under $parent.');
    }
    if (!colorGroupMembership.containsKey(item['color'])) {
      throw StateError('${spec.id}: colour ${item['color']} not in taxonomy.');
    }
    for (final tag in item['styleTags'] as List<String>) {
      if (!styleTagOptions.contains(tag)) {
        throw StateError('${spec.id}: style tag $tag outside enum.');
      }
    }
    if (!seasonOptions.contains(item['season'])) {
      throw StateError('${spec.id}: season ${item['season']} outside enum.');
    }
    if (!genderOptions.contains(item['gender'])) {
      throw StateError('${spec.id}: gender ${item['gender']} outside enum.');
    }
    if (requiresFit(subcategory) && !item.containsKey('fit')) {
      throw StateError('${spec.id}: $subcategory is missing a fit.');
    }
  }
}

List<Map<String, dynamic>> _buildOutfits(
  PersonaSpec spec,
  List<Map<String, dynamic>> items,
  Random rng,
) {
  List<Map<String, dynamic>> byType(String type) =>
      items.where((item) => item['categoryType'] == type).toList();

  final tops = items
      .where((item) => item['categoryType'] == 'top')
      .toList();
  final bottoms = byType('bottom');
  final shoes = byType('shoes');
  final accessories = items
      .where((item) => item['parentCategory'] == 'Accessories')
      .toList();

  if (tops.isEmpty || bottoms.isEmpty || shoes.isEmpty) {
    throw StateError('${spec.id}: cannot build outfits without tops, bottoms and shoes.');
  }

  final outfits = <Map<String, dynamic>>[];
  for (var i = 0; i < kOutfitsPerPersona; i++) {
    final top = tops[rng.nextInt(tops.length)];
    final bottom = bottoms[rng.nextInt(bottoms.length)];
    final shoe = shoes[rng.nextInt(shoes.length)];
    final accessory =
        accessories.isEmpty ? null : accessories[rng.nextInt(accessories.length)];
    outfits.add(<String, dynamic>{
      'localId': '${spec.id}-outfit-${i + 1}',
      'occasion': spec.occasions[i % spec.occasions.length],
      'score': 78 + rng.nextInt(15),
      'topLocalId': top['localId'],
      'bottomLocalId': bottom['localId'],
      'shoesLocalId': shoe['localId'],
      if (accessory != null) 'accessoryLocalId': accessory['localId'],
      'summary':
          '${top['subcategory']} + ${bottom['subcategory']} + ${shoe['subcategory']}',
    });
  }
  return outfits;
}
