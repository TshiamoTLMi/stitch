import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/clothing_item.dart';

/// Canonical outfit templates the engine validates against. The `ruleId` matches a
/// `structure` id in `assets/ml_seed_rules.json`.
enum AffinityStructure {
  standard('standard'),
  outerwearLayered('outerwear_layered'),
  onePiece('one_piece'),
  onePieceLayered('one_piece_layered');

  const AffinityStructure(this.ruleId);

  final String ruleId;

  static AffinityStructure? fromRuleId(String id) {
    for (final value in AffinityStructure.values) {
      if (value.ruleId == id) return value;
    }
    return null;
  }
}

/// The structural role an item plays inside an outfit.
enum OutfitSlot { top, bottom, onePiece, outerwear, shoes, accessory }

/// Maps a DLS parent category onto its structural slot. Reuses the taxonomy's
/// own parent-category names so no second taxonomy is introduced.
OutfitSlot slotForParentCategory(String parentCategory) {
  switch (parentCategory) {
    case 'Tops':
    case 'Activewear & Leisure':
    case 'Essentials & Intimates':
      return OutfitSlot.top;
    case 'Bottoms':
      return OutfitSlot.bottom;
    case 'Dresses & Jumpsuits':
      return OutfitSlot.onePiece;
    case 'Outerwear':
      return OutfitSlot.outerwear;
    case 'Footwear':
      return OutfitSlot.shoes;
    case 'Accessories':
      return OutfitSlot.accessory;
    default:
      return OutfitSlot.top;
  }
}

/// Result of scoring one candidate outfit. Every component is normalised to
/// `[0.0, 1.0]`; `styleMatchPercent` is the weighted result in `[0, 100]`.
class AffinityBreakdown {
  const AffinityBreakdown({
    required this.structure,
    required this.style,
    required this.event,
    required this.weather,
    required this.color,
    required this.category,
    required this.styleMatchPercent,
    required this.reasons,
    required this.contributions,
  });

  final AffinityStructure? structure;
  final double style;
  final double event;
  final double weather;
  final double color;
  final double category;
  final int styleMatchPercent;

  /// User-facing explanation (Principle V: explainable recommendations).
  final List<String> reasons;

  /// Rule identifiers that contributed, used later for feedback adaptation.
  final List<String> contributions;

  bool get isValid => structure != null;
}

class _StructureRule {
  const _StructureRule({
    required this.id,
    required this.required,
    required this.optional,
    required this.suitability,
  });

  final String id;
  final Set<String> required;
  final Set<String> optional;
  final double suitability;
}

class _WeatherClass {
  const _WeatherClass({
    required this.id,
    required this.scores,
    required this.waterproof,
    required this.layering,
  });

  final String id;
  final Map<String, double> scores;
  final bool waterproof;
  final String layering;
}

class _Validation {
  const _Validation(this.structure, this.reason);

  final AffinityStructure? structure;
  final String? reason;

  bool get isValid => structure != null;
}

/// Local-first, weighted affinity engine. Pure and synchronous, so a candidate
/// set can be scored in an isolate without changing this code.
class AffinityEngine {
  AffinityEngine(
    String rulesJson, {
    Map<String, double>? weightOverrides,
  }) {
    _parse(rulesJson);
    _sourceJson = rulesJson;
    if (weightOverrides != null) applyWeights(weightOverrides);
  }

  /// The raw rule matrix this engine was parsed from. Handing this to a
  /// background isolate avoids re-reading the asset bundle off the main thread.
  late final String? _sourceJson;

  String? get sourceJson => _sourceJson;

  /// Loads the matrix from a bundled asset at runtime.
  static Future<AffinityEngine> fromAsset(String assetPath) async {
    return AffinityEngine(await rootBundle.loadString(assetPath));
  }

  late final Map<String, _StructureRule> _structures;
  late final Map<String, Map<String, double>> _styleEvent;
  late final Map<String, _WeatherClass> _weatherBySubcategory;
  late final Set<String> _weatherConditions;
  late final Map<String, Map<String, double>> _colorMatrix;
  late final Map<String, double> _colorPatternScores;
  // Deliberately NOT `late final`: `applyWeights()` re-assigns it when user
  // feedback is applied, which would throw on a second write.
  late Map<String, double> _weights;

  Set<String> get weatherConditions => _weatherConditions;
  Map<String, double> get defaultWeights => Map.unmodifiable(_weights);

  double weight(String key) => _weights[key] ?? 0.0;

  /// Applies user-adapted weights (from `FeedbackStore`) over the matrix
  /// defaults. Used to make past feedback affect future scoring.
  ///
  /// Expects a complete, normalised five-key vector (the store guarantees this);
  /// merging a partial map would leave the total above 1.0.
  void applyWeights(Map<String, double> overrides) {
    _weights = <String, double>{..._weights, ...overrides};
  }

  /// Cheap, deterministic per-item prior in `[0, 1]`, used to prune wardrobe
  /// buckets before candidate generation so a large wardrobe cannot explode
  /// combinatorially. It is a heuristic, not the final score.
  double itemPrior(
    ClothingItem item, {
    String occasion = '',
    String? weather,
    String? targetStyle,
  }) {
    var event = 0.5;
    final eventKey = canonicalEvent(occasion);
    if (eventKey.isNotEmpty) {
      var best = 0.0;
      for (final tag in item.styleTags) {
        final score = _styleEvent[_normalizeStyleKey(tag)]?[eventKey];
        if (score != null && score > best) best = score;
      }
      if (best > 0) event = best;
    }

    var weatherScore = 0.5;
    final condition = canonicalWeather(weather ?? '');
    if (condition.isNotEmpty && _weatherConditions.contains(condition)) {
      weatherScore =
          _weatherBySubcategory[item.subcategory]?.scores[condition] ?? 0.5;
    }

    var style = 1.0;
    final wanted = _normalizeStyleKey(targetStyle ?? '');
    if (wanted.isNotEmpty) {
      style = item.styleTags.map(_normalizeStyleKey).contains(wanted) ? 1.0 : 0.0;
    }

    return _clamp01(0.5 * event + 0.3 * weatherScore + 0.2 * style);
  }


  void _parse(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;

    _structures = <String, _StructureRule>{};
    for (final raw in root['categoryCompatibility'] as List) {
      final rule = raw as Map<String, dynamic>;
      _structures[rule['structure'] as String] = _StructureRule(
        id: rule['id'] as String,
        required: (rule['required'] as List).cast<String>().toSet(),
        optional: ((rule['optional'] as List?) ?? const <String>[])
            .cast<String>()
            .toSet(),
        suitability: (rule['suitability'] as num).toDouble(),
      );
    }

    _styleEvent = <String, Map<String, double>>{};
    for (final raw in root['styleEventAffinity'] as List) {
      final rule = raw as Map<String, dynamic>;
      // Both sides are normalised so lookups are case/space insensitive.
      final styleKey = _normalizeStyleKey(rule['style'] as String);
      final eventKey = _normalizeEventKey(rule['event'] as String);
      _styleEvent.putIfAbsent(styleKey, () => <String, double>{})[eventKey] =
          (rule['score'] as num).toDouble();
    }

    final weather = root['weatherSuitability'] as Map<String, dynamic>;
    _weatherConditions = (weather['conditions'] as List)
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toSet();
    _weatherBySubcategory = <String, _WeatherClass>{};
    for (final raw in weather['classes'] as List) {
      final cls = raw as Map<String, dynamic>;
      final entry = _WeatherClass(
        id: cls['id'] as String,
        scores: (cls['scores'] as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        waterproof: (cls['waterproof'] as bool?) ?? false,
        layering: (cls['layering'] as String?) ?? 'single',
      );
      for (final sub in (cls['subcategories'] as List).cast<String>()) {
        _weatherBySubcategory[sub] = entry;
      }
    }

    final harmony = root['colorHarmony'] as Map<String, dynamic>;
    _colorMatrix = (harmony['matrix'] as Map).map(
      (row, cells) => MapEntry(
        row as String,
        (cells as Map)
            .map((c, v) => MapEntry(c as String, (v as num).toDouble())),
      ),
    );
    _colorPatternScores = <String, double>{};
    for (final raw in harmony['patterns'] as List) {
      final pattern = raw as Map<String, dynamic>;
      _colorPatternScores[pattern['pattern'] as String] =
          (pattern['score'] as num).toDouble();
    }

    _weights = (root['defaultWeights'] as Map)
        .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
  }

  /// Validates a candidate and reports the canonical template it represents.
  ///
  /// Rejects: empty candidates, missing/duplicate footwear, multiple tops or
  /// bottoms, multiple one-pieces, multiple outer layers, and combinations that
  /// overlap (a dress/jumpsuit together with a top or a separate bottom).
  _Validation _validateStructure(List<ClothingItem> items) {
    if (items.isEmpty) {
      return const _Validation(null, 'No items in candidate.');
    }

    final counts = <OutfitSlot, int>{};
    for (final item in items) {
      final slot = slotForParentCategory(item.parentCategory);
      counts[slot] = (counts[slot] ?? 0) + 1;
    }

    if ((counts[OutfitSlot.shoes] ?? 0) != 1) {
      return const _Validation(
          null, 'Every outfit needs exactly one pair of footwear.');
    }
    if ((counts[OutfitSlot.bottom] ?? 0) > 1) {
      return const _Validation(
          null, 'An outfit cannot contain more than one bottom.');
    }
    if ((counts[OutfitSlot.top] ?? 0) > 1) {
      return const _Validation(
          null, 'An outfit cannot contain more than one top.');
    }
    if ((counts[OutfitSlot.onePiece] ?? 0) > 1) {
      return const _Validation(
          null, 'An outfit cannot contain more than one dress or jumpsuit.');
    }
    if ((counts[OutfitSlot.outerwear] ?? 0) > 1) {
      return const _Validation(
          null, 'An outfit cannot contain more than one outerwear layer.');
    }
    if ((counts[OutfitSlot.accessory] ?? 0) > 2) {
      return const _Validation(
          null, 'An outfit can carry at most two accessories.');
    }

    final hasOnePiece = (counts[OutfitSlot.onePiece] ?? 0) > 0;
    final hasTop = (counts[OutfitSlot.top] ?? 0) > 0;
    final hasBottom = (counts[OutfitSlot.bottom] ?? 0) > 0;
    final hasOuterwear = (counts[OutfitSlot.outerwear] ?? 0) > 0;

    if (hasOnePiece && hasTop) {
      return const _Validation(
          null, 'A dress or jumpsuit cannot be combined with a top.');
    }
    if (hasOnePiece && hasBottom) {
      return const _Validation(
          null, 'A dress or jumpsuit cannot be combined with a separate bottom.');
    }
    if (!hasOnePiece && !hasTop && !hasBottom) {
      return const _Validation(
          null, 'An outfit needs either a top and bottom, or a one-piece.');
    }

    final AffinityStructure structure;
    if (hasOnePiece) {
      structure = hasOuterwear
          ? AffinityStructure.onePieceLayered
          : AffinityStructure.onePiece;
    } else if (hasOuterwear) {
      if (!hasTop || !hasBottom) {
        return const _Validation(
            null, 'A layered outfit needs a top, a bottom and an outer layer.');
      }
      structure = AffinityStructure.outerwearLayered;
    } else {
      if (!hasTop || !hasBottom) {
        return const _Validation(
            null, 'A standard outfit needs both a top and a bottom.');
      }
      structure = AffinityStructure.standard;
    }

    return _Validation(structure, null);
  }

  /// Public, explainable structural check. Returns null when the candidate is
  /// structurally valid, otherwise a user-facing reason.
  String? rejectionReason(List<ClothingItem> items) =>
      _validateStructure(items).reason;

  /// Every canonical template the candidate satisfies. A well-formed candidate
  /// satisfies exactly one.
  List<AffinityStructure> validStructures(List<ClothingItem> items) {
    final result = _validateStructure(items);
    return result.isValid
        ? <AffinityStructure>[result.structure!]
        : const <AffinityStructure>[];
  }

  static const Map<AffinityStructure, String> _structureLabels =
      <AffinityStructure, String>{
    AffinityStructure.standard: 'Classic three-piece fit',
    AffinityStructure.outerwearLayered: 'Layered four-piece fit',
    AffinityStructure.onePiece: 'One-piece fit',
    AffinityStructure.onePieceLayered: 'Layered one-piece fit',
  };

  static String _normalizeStyleKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  static String _normalizeEventKey(String value) =>
      value.trim().toLowerCase();

  /// Occasion aliases so the existing UI dropdown values map onto the matrix.
  /// `Event` (shown in the generator UI) means `Formal event` in the rules.
  static const Map<String, String> eventAliases = <String, String>{
    'event': 'formal event',
    'office': 'work',
    'wedding': 'formal event',
    'graduation': 'formal event',
  };

  /// Weather aliases for the existing UI dropdown values (`Sunny`, `Rainy`).
  static const Map<String, String> weatherAliases = <String, String>{
    'sunny': 'warm',
    'rainy': 'rain',
  };

  /// One UI label per engine condition - no condition collapses into another.
  static const Map<String, String> weatherLabels = <String, String>{
    'hot': 'Hot',
    'warm': 'Warm',
    'mild': 'Mild',
    'cold': 'Cold',
    'freezing': 'Freezing',
    'rain': 'Rainy',
  };

  /// The dropdown label for an engine condition, defaulting to `Mild`.
  static String weatherLabelFor(String condition) =>
      weatherLabels[condition] ?? weatherLabels['mild']!;

  /// Canonical occasion key, or the normalised input when it has no alias.
  static String canonicalEvent(String value) {
    final key = _normalizeEventKey(value);
    return eventAliases[key] ?? key;
  }

  /// Canonical weather condition key.
  static String canonicalWeather(String value) {
    final key = _normalizeEventKey(value);
    return weatherAliases[key] ?? key;
  }

  /// The contrasting condition offered as a backup outfit: rain when the
  /// forecast is dry, and a dry mild fit when it is already raining.
  static String alternateWeatherFor(String? weather) =>
      canonicalWeather(weather ?? '') == 'rain' ? 'mild' : 'rain';

  static String _normStyle(String value) => _normalizeStyleKey(value);

  static double _clamp01(double value) => value.clamp(0.0, 1.0);

  static String _pct(double value) => '${(value * 100).round()}%';

  /// Scores one candidate outfit.
  ///
  /// `Style Match % = round( 100 * Σ w_i · X_i )`, where every `X_i` is
  /// normalised to `[0.0, 1.0]` and the weights come from `defaultWeights`.
  /// Purely local: no network, no LLM.
  AffinityBreakdown score({
    required List<ClothingItem> items,
    String occasion = '',
    String? weather,
    String? targetStyle,
  }) {
    final validation = _validateStructure(items);
    if (!validation.isValid) {
      return AffinityBreakdown(
        structure: null,
        style: 0,
        event: 0,
        weather: 0,
        color: 0,
        category: 0,
        styleMatchPercent: 0,
        reasons: <String>[validation.reason!],
        contributions: const <String>[],
      );
    }

    final structure = validation.structure!;
    final contributions = <String>[];

    final style = _scoreStyle(items, targetStyle);
    final event = _scoreEvent(items, occasion, contributions);
    final weatherScore = _scoreWeather(items, weather, contributions);
    final color = _scoreColor(items, contributions);
    final category = _scoreCategory(structure, contributions);

    final weighted = weight('w_style') * style +
        weight('w_event') * event +
        weight('w_weather') * weatherScore +
        weight('w_color') * color +
        weight('w_category') * category;

    final percent = (weighted * 100).round().clamp(0, 100);

    return AffinityBreakdown(
      structure: structure,
      style: style,
      event: event,
      weather: weatherScore,
      color: color,
      category: category,
      styleMatchPercent: percent,
      reasons: _reasons(
        structure: structure,
        occasion: occasion,
        weather: weather,
        targetStyle: targetStyle,
        percent: percent,
        style: style,
        event: event,
        weatherScore: weatherScore,
        color: color,
        category: category,
      ),
      contributions: contributions,
    );
  }

  /// S - style coherence, or alignment with an explicit target style.
  double _scoreStyle(List<ClothingItem> items, String? targetStyle) {
    if (items.isEmpty) return 0.0;
    final counts = <String, int>{};
    for (final item in items) {
      for (final tag in item.styleTags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return 0.5;

    final wanted = _normStyle(targetStyle ?? '');
    if (wanted.isNotEmpty) {
      final hits = items
          .where((item) =>
              item.styleTags.map(_normStyle).contains(wanted))
          .length;
      return _clamp01(hits / items.length);
    }

    final dominant = counts.values.reduce((a, b) => a > b ? a : b);
    return _clamp01(dominant / items.length);
  }

  /// E - best style/occasion affinity per item, averaged.
  double _scoreEvent(
    List<ClothingItem> items,
    String occasion,
    List<String> contributions,
  ) {
    final key = canonicalEvent(occasion);
    if (key.isEmpty || items.isEmpty) return 0.5;

    var total = 0.0;
    var matched = 0;
    for (final item in items) {
      var best = 0.0;
      String? bestRule;
      for (final tag in item.styleTags) {
        final score = _styleEvent[_normStyle(tag)]?[key];
        if (score != null && score > best) {
          best = score;
          bestRule = 'style:$tag|event:$key';
        }
      }
      if (bestRule != null) {
        matched++;
        if (!contributions.contains(bestRule)) contributions.add(bestRule);
      }
      total += best;
    }
    if (matched == 0) return 0.5;
    return _clamp01(total / items.length);
  }

  /// W - mean weather-class suitability for the requested condition.
  double _scoreWeather(
    List<ClothingItem> items,
    String? weather,
    List<String> contributions,
  ) {
    final condition = canonicalWeather(weather ?? '');
    if (condition.isEmpty ||
        !_weatherConditions.contains(condition) ||
        items.isEmpty) {
      return 0.5;
    }

    var total = 0.0;
    for (final item in items) {
      final cls = _weatherBySubcategory[item.subcategory];
      if (cls == null) {
        total += 0.5;
        continue;
      }
      total += cls.scores[condition] ?? 0.5;
      contributions.add('weather:$condition|class:${cls.id}');
    }
    return _clamp01(total / items.length);
  }

  /// C - pairwise colour-group harmony blended with the outfit colour pattern.
  double _scoreColor(List<ClothingItem> items, List<String> contributions) {
    if (items.length < 2) return 0.6;

    var pairTotal = 0.0;
    var pairs = 0;
    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        final a = items[i].colorGroup;
        final b = items[j].colorGroup;
        pairTotal += _colorMatrix[a]?[b] ?? 0.5;
        pairs++;
        contributions.add('color:$a|$b');
      }
    }
    final pairwise = pairs == 0 ? 0.5 : pairTotal / pairs;

    final groups = items.map((item) => item.colorGroup).toList();
    final distinct = groups.toSet();
    final neutralCount = groups.where((g) => g == 'neutral').length;
    final hasWarm = groups.contains('warm');
    final hasCool = groups.contains('cool');

    final double patternScore;
    if (distinct.length == 1) {
      patternScore = _colorPatternScores['monochromatic'] ?? 0.9;
    } else if (neutralCount == 0) {
      patternScore = _colorPatternScores['all_accent'] ?? 0.35;
    } else if (hasWarm && hasCool) {
      patternScore = _colorPatternScores['complementary'] ?? 0.45;
    } else if (neutralCount * 2 >= groups.length) {
      patternScore = _colorPatternScores['neutral_dominant'] ?? 0.85;
    } else {
      patternScore = 0.6;
    }

    return _clamp01(0.7 * pairwise + 0.3 * patternScore);
  }

  /// K - structural suitability from the categoryCompatibility dimension.
  double _scoreCategory(AffinityStructure structure, List<String> contributions) {
    final rule = _structures[structure.ruleId];
    if (rule == null) return 0.5;
    contributions.add(rule.id);
    return _clamp01(rule.suitability);
  }

  List<String> _reasons({
    required AffinityStructure structure,
    required String occasion,
    required String? weather,
    required String? targetStyle,
    required int percent,
    required double style,
    required double event,
    required double weatherScore,
    required double color,
    required double category,
  }) {
    final context = <String>[];
    if (occasion.trim().isNotEmpty) context.add('for $occasion');
    if ((weather ?? '').trim().isNotEmpty) context.add('in $weather weather');
    if ((targetStyle ?? '').trim().isNotEmpty) {
      context.add('styled $targetStyle');
    }
    final suffix = context.isEmpty ? '' : ' ${context.join(' ')}';
    return <String>[
      '${_structureLabels[structure]}$suffix scores $percent% style match.',
      'Style ${_pct(style)}, event ${_pct(event)}, weather ${_pct(weatherScore)}, '
          'colour ${_pct(color)}, structure ${_pct(category)}.',
    ];
  }
}


