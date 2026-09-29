import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services/mock_wardrobe_seeder.dart';
import '../models/clothing_item.dart';
import '../services/wardrobe_repository.dart';

class WardrobeController extends ChangeNotifier {
  WardrobeController(this._wardrobeRepository);

  final WardrobeRepository _wardrobeRepository;
  StreamSubscription<List<ClothingItem>>? _subscription;
  final Completer<void> _firstSync = Completer<void>();

  /// Real, Firestore-backed items for the signed-in user.
  List<ClothingItem> _cachedItems = <ClothingItem>[];

  /// Development/demo rows injected locally in dev builds. They are never
  /// written to Firestore, so a production account stays clean.
  final List<ClothingItem> _localSeedItems = <ClothingItem>[];

  bool _isSyncing = false;
  bool _isDisposed = false;

  /// The real wardrobe plus any development seed rows, de-duplicated by id.
  List<ClothingItem> get items {
    if (_localSeedItems.isEmpty) return _cachedItems;
    final ids = _cachedItems.map((item) => item.id).toSet();
    return <ClothingItem>[
      ..._cachedItems,
      ..._localSeedItems.where((seed) => !ids.contains(seed.id)),
    ];
  }

  bool get isSyncing => _isSyncing;

  /// True when development seed data is currently merged into the wardrobe.
  bool get hasLocalSeedItems => _localSeedItems.isNotEmpty;

  /// Bootstrap entry point: binds the live wardrobe, then (dev builds only)
  /// injects the bundled seed dataset once the real wardrobe is known.
  Future<void> initialize(String userId) async {
    bindStream(userId);
    // Wait for the first real sync so we never seed on top of a real wardrobe.
    await _firstSync.future
        .timeout(const Duration(seconds: 8), onTimeout: () {});
    await _maybeSeedDevelopmentWardrobe(userId);
  }

  void bindStream(String userId) {
    _subscription?.cancel();
    _isSyncing = true;
    notifyListeners();

    _subscription = _wardrobeRepository.streamItems(userId).listen((event) {
      _cachedItems = event;
      _isSyncing = false;
      if (!_firstSync.isCompleted) _firstSync.complete();
      notifyListeners();
    }, onError: (_) {
      _isSyncing = false;
      if (!_firstSync.isCompleted) _firstSync.complete();
      notifyListeners();
    });
  }

  Future<void> _maybeSeedDevelopmentWardrobe(String userId) async {
    try {
      final seeder = MockWardrobeSeeder(repository: _wardrobeRepository);
      if (!seeder.isDevelopment) return;
      final result = await seeder.seedIfEmpty(userId: userId);
      if (!result.seeded || _isDisposed) return;
      applyLocalSeedItems(result.items);
    } catch (_) {
      // Seeding is a developer convenience; never break the app for it.
    }
  }

  Future<void> updateItem({
    required String id,
    String? category,
    String? color,
    List<String>? styleTags,
    String? status,
  }) {
    return _wardrobeRepository.updateItem(
      id: id,
      category: category,
      color: color,
      styleTags: styleTags,
      status: status,
    );
  }

  Future<void> deleteItem(String id) {
    return _wardrobeRepository.deleteClothingItem(id);
  }

  /// Injects development/demo seed items into the local view only. Nothing is
  /// written to Firestore, so a production account is never polluted.
  void applyLocalSeedItems(List<ClothingItem> items) {
    if (items.isEmpty || _isDisposed) return;
    final existing = <String>{
      ..._cachedItems.map((item) => item.id),
      ..._localSeedItems.map((item) => item.id),
    };
    for (final item in items) {
      if (existing.add(item.id)) _localSeedItems.add(item);
    }
    notifyListeners();
  }

  void clearCache() {
    _cachedItems = <ClothingItem>[];
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
