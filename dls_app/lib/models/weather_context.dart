/// A local weather snapshot mapped into the DLS engine's condition vocabulary.
///
/// [condition] is always one of: `hot`, `warm`, `mild`, `cold`, `freezing`, `rain`
/// (matching `weatherSuitability` in `assets/ml_seed_rules.json`).
class WeatherContext {
  const WeatherContext({
    required this.temperatureC,
    required this.condition,
    required this.source,
    this.wmoCode,
    this.observedAt,
    this.locationName,
  });

  final double temperatureC;
  final String condition;

  /// `live` (from Open-Meteo), `cache` (offline) or `default` (neutral fallback).
  final String source;

  final int? wmoCode;
  final DateTime? observedAt;

  /// The place this reading came from, when a location is configured.
  final String? locationName;

  static const String sourceLive = 'live';
  static const String sourceCache = 'cache';
  static const String sourceDefault = 'default';

  bool get isLive => source == sourceLive;
  bool get isCached => source == sourceCache;
  bool get isDefault => source == sourceDefault;
  bool get isRain => condition == 'rain';

  String get conditionLabel {
    switch (condition) {
      case 'hot':
        return 'Hot';
      case 'warm':
        return 'Warm';
      case 'mild':
        return 'Mild';
      case 'cold':
        return 'Cold';
      case 'freezing':
        return 'Freezing';
      case 'rain':
        return 'Rain';
      default:
        return condition;
    }
  }

  String get label => '${temperatureC.round()}°C $conditionLabel';

  /// Label including the active place, e.g. `24°C Rain - Cape Town`.
  String get locationLabel {
    final place = locationName;
    return (place == null || place.isEmpty) ? label : '$label - $place';
  }

  /// True when this reading is old enough to be treated as stale.
  bool isStale({Duration maxAge = const Duration(hours: 3)}) {
    final at = observedAt;
    if (at == null) return true;
    return DateTime.now().toUtc().difference(at) > maxAge;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'temperatureC': temperatureC,
        'condition': condition,
        'wmoCode': wmoCode,
        'observedAt': observedAt?.toIso8601String(),
        'locationName': locationName,
      };

  factory WeatherContext.fromJson(Map<String, dynamic> json) {
    return WeatherContext(
      temperatureC: (json['temperatureC'] as num?)?.toDouble() ?? 22.0,
      condition: (json['condition'] as String?) ?? 'warm',
      source: sourceCache,
      wmoCode: (json['wmoCode'] as num?)?.toInt(),
      observedAt: DateTime.tryParse((json['observedAt'] as String?) ?? ''),
      locationName: json['locationName'] as String?,
    );
  }
}
