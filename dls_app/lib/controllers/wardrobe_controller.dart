import 'package:flutter/material.dart';
import 'dart:async';

import '../models/clothing_item.dart';
import '../services/wardrobe_repository.dart';

class WardrobeController extends ChangeNotifier {
  WardrobeController(this._wardrobeRepository);

  final WardrobeRepository _wardrobeRepository;
  StreamSubscription<List<ClothingItem>>? _subscription;

  List<ClothingItem> _cachedItems = <ClothingItem>[];
  bool _isSyncing = false;

  List<ClothingItem> get items => _cachedItems;
  bool get isSyncing => _isSyncing;

  void bindStream(String userId) {
    _subscription?.cancel();
    _isSyncing = true;
    notifyListeners();

    _subscription = _wardrobeRepository.streamItems(userId).listen((event) {
      _cachedItems = event;
      _isSyncing = false;
      notifyListeners();
    });
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

  void clearCache() {
    _cachedItems = <ClothingItem>[];
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
