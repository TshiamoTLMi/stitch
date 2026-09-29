import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show rootBundle;

import '../../models/clothing_item.dart';
import '../../services/wardrobe_repository.dart';

/// Outcome of a seeding attempt. [reason] is always populated so the caller can
/// explain itself to the user or a test.
class MockSeedResult {
  const MockSeedResult({
    required this.seeded,
    required this.itemCount,
    required this.reason,
    this.items = const <ClothingItem>[],
  });

  final bool seeded;
  final int itemCount;
  final String reason;

  /// The items that were injected, so the caller can surface them locally.
  final List<ClothingItem> items;
}

/// Injects the bundled development seed wardrobe for local/demo builds only.
///
/// **Dev/Prod isolation:** seeding is gated on `kDebugMode` or the
/// `--dart-define=DLS_DEMO_MODE=true` flag. In a production build this class is
/// a no-op and a real user's empty wardrobe stays empty - fake data is never
/// written to a real account.
class MockWardrobeSeeder {
  MockWardrobeSeeder({
    required WardrobeRepository repository,
    Future<String> Function(String assetPath)? assetReader,
    bool? developmentOverride,
  })  : _repository = repository,
        _assetReader = assetReader ?? rootBundle.loadString,
        _developmentOverride = developmentOverride;

  static const String seedAssetPath = 'assets/seed/wardrobe_seed.json';

  /// Opt-in demo seeding for a non-debug build, e.g. a pre-prod build.
  static const bool demoEnvFlag = bool.fromEnvironment('DLS_DEMO_MODE');

  final WardrobeRepository _repository;
  final Future<String> Function(String assetPath) _assetReader;
  final bool? _developmentOverride;

  /// True when demo data is permitted in this build.
  bool get isDevelopment =>
      _developmentOverride ?? (kDebugMode || demoEnvFlag);

  /// Parses the seed asset into [ClothingItem]s. Invalid rows are skipped rather
  /// than failing the whole load.
  static List<ClothingItem> parseSeedJson(String source, {String? userId}) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) return const <ClothingItem>[];
    final rawItems = decoded['items'];
    if (rawItems is! List) return const <ClothingItem>[];

    final items = <ClothingItem>[];
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['id'];
      if (id is! String || id.isEmpty) continue;
      final item = ClothingItem.fromMap(id, raw);
      items.add(userId == null ? item : item.copyWith(userId: userId));
    }
    return items;
  }

  Future<List<ClothingItem>> loadSeedItems({String? userId}) async {
    final source = await _assetReader(seedAssetPath);
    return parseSeedJson(source, userId: userId);
  }

  /// Seeds the local wardrobe when allowed and the wardrobe is empty.
  /// Pass `force: true` (dev settings) to re-seed.
  Future<MockSeedResult> seedIfEmpty({
    String? userId,
    bool force = false,
  }) async {
    if (!isDevelopment) {
      return const MockSeedResult(
        seeded: false,
        itemCount: 0,
        reason: 'Seed data is disabled outside development builds.',
      );
    }

    final existing = _repository.cachedItems;
    if (existing.isNotEmpty && !force) {
      return MockSeedResult(
        seeded: false,
        itemCount: existing.length,
        reason: 'Wardrobe already has items; skipping seed.',
      );
    }

    final items = await loadSeedItems(userId: userId);
    if (items.isEmpty) {
      return const MockSeedResult(
        seeded: false,
        itemCount: 0,
        reason: 'Seed asset contained no usable items.',
      );
    }

    _repository.seedLocalItems(<ClothingItem>[...existing, ...items]);
    return MockSeedResult(
      seeded: true,
      itemCount: items.length,
      reason: 'Seeded ${items.length} development items.',
      items: items,
    );
  }
}
