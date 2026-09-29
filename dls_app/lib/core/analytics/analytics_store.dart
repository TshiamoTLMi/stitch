import 'dart:convert';

import '../../models/clothing_item.dart';
import '../storage/kv_store.dart';

/// A single logged outfit generation.
///
/// Captures the full scoring context so the trend chart can show *why* a score
/// was what it was, not just the headline number.
class OutfitLogEntry {
  const OutfitLogEntry({
    required this.timestamp,
    required this.occasion,
    required this.weather,
    required this.styleMatchPercent,
    required this.scoreStyle,
    required this.scoreEvent,
    required this.scoreWeather,
    required this.scoreColor,
    required this.scoreCategory,
    required this.itemIds,
    this.occasionLabel = '',
  });

  final DateTime timestamp;
  final String occasion;
  final String weather;

  /// Total Style Match % (0-100).
  final int styleMatchPercent;

  // The five affinity variables: S (style), E (event), W (weather),
  // C (colour) and K (category compatibility).
  final double scoreStyle;
  final double scoreEvent;
  final double scoreWeather;
  final double scoreColor;
  final double scoreCategory;

  /// Ids of the garments in this outfit; drives wear tracking.
  final List<String> itemIds;

  /// Pre-rendered chip label, e.g. "Work".
  final String occasionLabel;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestamp': timestamp.toIso8601String(),
        'occasion': occasion,
        'occasionLabel': occasionLabel,
        'weather': weather,
        'styleMatchPercent': styleMatchPercent,
        'scores': <String, double>{
          'style': scoreStyle,
          'event': scoreEvent,
          'weather': scoreWeather,
          'color': scoreColor,
          'category': scoreCategory,
        },
        'itemIds': itemIds,
      };

  factory OutfitLogEntry.fromJson(Map<String, dynamic> json) {
    final scores =
        (json['scores'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    double score(String key) => (scores[key] as num?)?.toDouble() ?? 0.0;

    return OutfitLogEntry(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      occasion: json['occasion'] as String? ?? '',
      occasionLabel: json['occasionLabel'] as String? ?? '',
      weather: json['weather'] as String? ?? '',
      styleMatchPercent: (json['styleMatchPercent'] as num?)?.toInt() ?? 0,
      scoreStyle: score('style'),
      scoreEvent: score('event'),
      scoreWeather: score('weather'),
      scoreColor: score('color'),
      scoreCategory: score('category'),
      itemIds:
          List<String>.from(json['itemIds'] as List? ?? const <String>[]),
    );
  }
}

/// A Like/Dislike reaction, recorded with the weight vector active at the time.
class FeedbackLogEntry {
  const FeedbackLogEntry({
    required this.timestamp,
    required this.liked,
    required this.styleMatchPercent,
    required this.weightSnapshot,
  });

  final DateTime timestamp;

  /// `true` = liked, `false` = disliked.
  final bool liked;

  /// The Style Match % the user was reacting to.
  final int styleMatchPercent;

  /// The active weights, so past feedback stays explainable.
  final Map<String, double> weightSnapshot;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestamp': timestamp.toIso8601String(),
        'liked': liked,
        'styleMatchPercent': styleMatchPercent,
        'weightSnapshot': weightSnapshot,
      };

  factory FeedbackLogEntry.fromJson(Map<String, dynamic> json) {
    final raw =
        (json['weightSnapshot'] as Map?) ?? const <String, dynamic>{};
    return FeedbackLogEntry(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      liked: json['liked'] as bool? ?? false,
      styleMatchPercent: (json['styleMatchPercent'] as num?)?.toInt() ?? 0,
      weightSnapshot: raw.map(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      ),
    );
  }
}

/// Append-only local log of outfits generated and feedback given.
///
/// Persisted to `style_analytics.json` through [KvStore], which means an atomic
/// file on Android and `localStorage` in a browser.
///
/// [QA TEST POINT] Analytics persistence
/// - Generate an outfit, force-kill the app, relaunch: the Style History log
///   must still list that outfit with the same Style Match %.
/// - Press Like then Dislike: both entries appear, newest first.
/// - On a release APK, clearing app data empties the history (no seeding).
class AnalyticsStore {
  AnalyticsStore({KvStore? store}) : _injected = store;

  /// File name in the documents directory (Android) / localStorage (web).
  static const String fileName = 'style_analytics.json';

  /// Oldest rows are pruned past these caps so the log cannot grow unbounded.
  static const int maxOutfitEntries = 200;
  static const int maxFeedbackEntries = 200;

  final KvStore? _injected;
  KvStore? _resolved;

  /// Cached in memory so the UI can render immediately after a load.
  List<OutfitLogEntry> _outfits = <OutfitLogEntry>[];
  List<FeedbackLogEntry> _feedback = <FeedbackLogEntry>[];

  /// Both are newest-first.
  List<OutfitLogEntry> get outfitEntries => List.unmodifiable(_outfits);
  List<FeedbackLogEntry> get feedbackEntries => List.unmodifiable(_feedback);

  /// Lazily resolves the platform store (file on Android, localStorage on web).
  Future<KvStore> _store() async =>
      _resolved ??= _injected ?? await createDefaultKvStore();

  /// Reads the log. Never throws: a corrupt file yields an empty log.
  Future<void> load() async {
    try {
      final raw = await (await _store()).read(fileName);
      if (raw == null || raw.isEmpty) {
        _outfits = <OutfitLogEntry>[];
        _feedback = <FeedbackLogEntry>[];
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _outfits = (decoded['outfits'] as List? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(OutfitLogEntry.fromJson)
          .toList();
      _feedback = (decoded['feedback'] as List? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FeedbackLogEntry.fromJson)
          .toList();
    } catch (_) {
      // Corrupt or unreadable store: start clean rather than crash the page.
      _outfits = <OutfitLogEntry>[];
      _feedback = <FeedbackLogEntry>[];
    }
  }

  /// Single atomic write of the whole log.
  Future<void> _flush() async {
    try {
      await (await _store()).write(fileName, jsonEncode(<String, dynamic>{
        'version': 1,
        'outfits': _outfits.map((e) => e.toJson()).toList(),
        'feedback': _feedback.map((e) => e.toJson()).toList(),
      }));
    } catch (_) {
      // Losing an analytics write must never break generation or feedback.
    }
  }

  /// Records a generated outfit, newest first, pruning past the cap.
  ///
  /// [QA TEST POINT] Generate three outfits in a row: Style History shows
  /// three entries, newest at the top, each with its own Style Match %.
  Future<void> logOutfit(OutfitLogEntry entry) async {
    _outfits = <OutfitLogEntry>[entry, ..._outfits];
    if (_outfits.length > maxOutfitEntries) {
      _outfits = _outfits.sublist(0, maxOutfitEntries);
    }
    await _flush();
  }

  /// Records a Like/Dislike together with the weights that were active.
  Future<void> logFeedback(FeedbackLogEntry entry) async {
    _feedback = <FeedbackLogEntry>[entry, ..._feedback];
    if (_feedback.length > maxFeedbackEntries) {
      _feedback = _feedback.sublist(0, maxFeedbackEntries);
    }
    await _flush();
  }

  /// Applies a wear to every garment in [entry] and returns the updated list.
  ///
  /// Wear tracking is deliberately a pure function: the analytics page can call
  /// it to update counters instantly, and persisting the new counts back to
  /// Firestore stays the caller's responsibility.
  ///
  /// [QA TEST POINT] Log an outfit of 3 garments, then open Analytics: those 3
  /// leave the "unworn" shelf and the utilisation rate rises.
  static List<ClothingItem> applyWear(
    List<ClothingItem> wardrobe,
    OutfitLogEntry entry, {
    DateTime? wornAt,
  }) {
    final when = wornAt ?? entry.timestamp;
    final worn = entry.itemIds.toSet();
    return wardrobe
        .map(
          (item) => worn.contains(item.id)
              ? item.copyWith(
                  wearCount: item.wearCount + 1,
                  lastWornDate: when,
                )
              : item,
        )
        .toList(growable: false);
  }
}
