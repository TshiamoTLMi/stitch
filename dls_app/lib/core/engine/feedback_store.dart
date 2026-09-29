import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../storage/kv_store.dart';
import 'affinity_engine.dart';

/// Which scoring dimensions a contribution key implicates.
///
/// `style:formal|event:work` implicates both the style and the event dimension,
/// so a single Like/Dislike nudges exactly the dimensions that produced the
/// recommendation. Unrelated dimensions are never touched.
Set<String> dimensionsForContribution(String key) {
  if (key.startsWith('cc-')) return const <String>{'w_category'};
  if (key.startsWith('style:')) return const <String>{'w_style', 'w_event'};
  if (key.startsWith('weather:')) return const <String>{'w_weather'};
  if (key.startsWith('color:') || key.startsWith('colorPattern:')) {
    return const <String>{'w_color'};
  }
  return const <String>{};
}

/// The persisted weight vector plus light provenance.
class FeedbackWeights {
  FeedbackWeights(
    this.values, {
    this.feedbackCount = 0,
    this.updatedAt,
  });

  final Map<String, double> values;
  final int feedbackCount;
  final DateTime? updatedAt;

  double get total => values.values.fold<double>(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 1,
        'weights': values,
        'feedbackCount': feedbackCount,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory FeedbackWeights.fromJson(Map<String, dynamic> json) {
    final raw = (json['weights'] as Map?) ?? const <String, dynamic>{};
    return FeedbackWeights(
      raw.map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      feedbackCount: (json['feedbackCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? ''),
    );
  }

  /// Returns a copy with `defaultWeights` applied to the five dimension keys.
  FeedbackWeights withDefaults(Map<String, double> defaults) {
    final merged = <String, double>{
      for (final key in defaults.keys) key: defaults[key]!,
      ...values,
    };
    return FeedbackWeights(merged, feedbackCount: feedbackCount, updatedAt: updatedAt);
  }
}

/// Persists the user's adapted scoring weights in
/// `<app documents>/user_weights.json` using atomic replace semantics.
class FeedbackStore {
  FeedbackStore({
    AffinityEngine? engine,
    Future<Directory> Function()? directoryProvider,
    this.learningRate = defaultLearningRate,
    this.fileName = defaultFileName,
  })  : _engine = engine,
        _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  static const String defaultFileName = 'user_weights.json';
  static const String tempSuffix = '.tmp';
  static const double defaultLearningRate = 0.1;

  /// Matches `defaultWeights` in `assets/ml_seed_rules.json`; used when no
  /// engine is injected so the store still boots.
  static const Map<String, double> fallbackDefaults = <String, double>{
    'w_style': 0.25,
    'w_event': 0.25,
    'w_weather': 0.2,
    'w_color': 0.15,
    'w_category': 0.15,
  };

  final AffinityEngine? _engine;
  final Future<Directory> Function() _directoryProvider;
  final double learningRate;
  final String fileName;

  KvStore? _kvStore;

  Map<String, double> get defaults =>
      _engine?.defaultWeights ?? fallbackDefaults;

  Future<Directory> resolveDirectory() => _directoryProvider();

  Future<File> targetFile() async {
    final dir = await resolveDirectory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Platform-appropriate persistence.
  ///
  /// On Android/iOS this is the atomic file written by [writeAtomically]. On
  /// web -- where `dart:io` and `path_provider` are unavailable and the call
  /// would otherwise throw -- it is `localStorage`, so adaptive learning
  /// survives a reload in Safari. Injectable for tests.
  ///
  /// [QA TEST POINT] Feedback persistence (`user_weights.json`)
  /// - Like an outfit, then check the documents directory: `user_weights.json`
  ///   exists and **no** `user_weights.json.tmp` is left behind.
  /// - Force-kill the app mid-write, relaunch: the file is either the old or
  ///   the new version, never a truncated one.
  /// - Repeat in Safari: the same round-trip works via `localStorage`.
  Future<KvStore> kvStore() async =>
      _kvStore ??= await createDefaultKvStore();

  /// Reads persisted weights, seeding from the rules matrix on first run.
  Future<FeedbackWeights> load() async {
    if (kIsWeb) {
      try {
        final raw = await (await kvStore()).read(fileName);
        if (raw != null) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            return FeedbackWeights.fromJson(decoded);
          }
        }
      } catch (_) {
        // Unreadable store: fall through to seeded defaults.
      }
      return FeedbackWeights(
        Map<String, double>.from(defaults),
        feedbackCount: 0,
      );
    }

    final file = await targetFile();
    if (!file.existsSync()) {
      final seeded =
          FeedbackWeights(Map<String, double>.from(defaults), feedbackCount: 0);
      return seeded;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return FeedbackWeights.fromJson(decoded);
      }
    } catch (_) {
      // Corrupt file: fall back to seeded defaults rather than crashing.
    }
    return FeedbackWeights(Map<String, double>.from(defaults));
  }

  /// The documented adaptation rule:
  /// `W_new = clamp(W_old + 0.1 * (F - W_old), 0.0, 1.0)`.
  ///
  /// Exposed as a pure function so the exact arithmetic can be unit tested
  /// without normalisation in the way.
  static double adapt(
    double oldWeight,
    double feedback, {
    double learningRate = defaultLearningRate,
  }) {
    final updated = oldWeight + learningRate * (feedback - oldWeight);
    return updated.clamp(0.0, 1.0);
  }

  /// Applies Like/Dislike feedback to the dimensions implicated by
  /// [contributions] (the keys returned by [AffinityBreakdown.contributions]).
  ///
  /// Uses [adapt], then re-normalises the whole vector to sum 1.0.
  Future<FeedbackWeights> applyFeedback({
    required Iterable<String> contributions,
    required double feedback,
  }) async {
    final current = await load();
    final active = <String>{};
    for (final key in contributions) {
      active.addAll(dimensionsForContribution(key));
    }
    if (active.isEmpty) return current;

    final target = feedback.clamp(0.0, 1.0);
    final values = <String, double>{};
    current.values.forEach((key, value) {
      values[key] = active.contains(key) ? adapt(value, target) : value;
    });

    final updated = FeedbackWeights(
      normalize(values),
      feedbackCount: current.feedbackCount + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    await writeAtomically(updated);
    return updated;
  }

  /// Atomic replace: write to `user_weights.json.tmp`, then rename over the
  /// target so a crash mid-write cannot corrupt the saved weights.
  Future<void> writeAtomically(FeedbackWeights weights) async {
    final payload = jsonEncode(weights.toJson());

    if (kIsWeb) {
      try {
        await (await kvStore()).write(fileName, payload);
      } catch (_) {
        // Storage unavailable (private browsing): keep the in-session value.
      }
      return;
    }

    final target = await targetFile();
    final temp = File('${target.path}$tempSuffix');
    await temp.writeAsString(payload, flush: true);
    try {
      await temp.rename(target.path);
    } catch (_) {
      if (await target.exists()) await target.delete();
      await temp.rename(target.path);
    }
  }

  /// Clamps to `[0, 1]` then scales so the vector sums to exactly 1.0.
  /// Any excess created by scaling is redistributed to weights with headroom.
  static Map<String, double> normalize(Map<String, double> values) {
    if (values.isEmpty) return const <String, double>{};

    final clamped = <String, double>{};
    values.forEach((key, value) {
      clamped[key] = value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;
    });

    var total = clamped.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      final uniform = 1.0 / clamped.length;
      return clamped.map((k, _) => MapEntry(k, uniform));
    }

    final result = <String, double>{};
    var excess = 0.0;
    for (final entry in clamped.entries) {
      final scaled = entry.value / total;
      if (scaled > 1.0) {
        result[entry.key] = 1.0;
        excess += scaled - 1.0;
      } else {
        result[entry.key] = scaled;
      }
    }

    if (excess > 0) {
      final withHeadroom = result.keys
          .where((k) => result[k]! < 1.0)
          .toList()
        ..sort((a, b) => result[b]!.compareTo(result[a]!));
      for (final key in withHeadroom) {
        if (excess <= 0) break;
        final room = 1.0 - result[key]!;
        final add = excess < room ? excess : room;
        result[key] = result[key]! + add;
        excess -= add;
      }
    }

    return result;
  }
}

