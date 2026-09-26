import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/clothing_item.dart';
import 'wardrobe_service.dart';

class WardrobeRepository {
  WardrobeRepository(
      {WardrobeService? service,
      List<ClothingItem> initialItems = const <ClothingItem>[]})
      : _service = service ?? WardrobeService() {
    _localItems.addEntries(initialItems.map((item) => MapEntry(item.id, item)));
  }

  final WardrobeService _service;
  final Map<String, ClothingItem> _localItems = <String, ClothingItem>{};

  List<ClothingItem> get cachedItems => List.unmodifiable(_localItems.values);

  Stream<List<ClothingItem>> streamItems(String userId) {
    return _service.streamItems(userId).map((items) {
      _localItems
        ..clear()
        ..addEntries(items.map((item) => MapEntry(item.id, item)));
      return List<ClothingItem>.unmodifiable(items);
    });
  }

  Future<void> updateItem({
    required String id,
    String? category,
    String? color,
    List<String>? styleTags,
    String? status,
  }) async {
    await _service.updateItem(
      id: id,
      category: category,
      color: color,
      styleTags: styleTags,
      status: status,
    );
  }

  List<ClothingItem> getItemsByCategory(String category) {
    final requested = _normalize(category);
    if (requested.isEmpty || requested == 'all' || requested == 'allitems') {
      return cachedItems;
    }

    return _localItems.values.where((item) {
      final type = _normalize(item.categoryType);
      final parent = _normalize(item.parentCategory);
      final subcategory = _normalize(item.subcategory);
      final aliases = <String>{type, parent, subcategory};

      if (requested == 'tops') {
        return type == 'top' ||
            type == 'full' ||
            parent == 'tops' ||
            parent == 'fullbody';
      }
      if (requested == 'bottoms') {
        return type == 'bottom' || parent == 'bottoms';
      }
      if (requested == 'shoes') {
        return type == 'shoes' || parent == 'footwear';
      }
      if (requested == 'accessories') {
        return type == 'accessory' || parent == 'accessories';
      }
      return aliases.contains(requested) ||
          aliases.contains(_categoryAlias(requested));
    }).toList(growable: false);
  }

  Future<void> deleteClothingItem(String itemId) async {
    final item = _localItems[itemId] ?? await _service.getItem(itemId);

    // Step 1: remove the app-owned JPEG before touching the remote record.
    await _deleteLocalImage(item);

    // Step 2: remove the local cache record and its Firestore source document.
    _localItems.remove(itemId);
    await _service.deleteFirestoreRecord(itemId);

    // Step 3: remove every known Storage backup, including legacy URL paths.
    if (item != null) {
      await _service.deleteStorageBackup(item);
    }
  }

  void seedLocalItems(Iterable<ClothingItem> items) {
    _localItems
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.id, item)));
  }

  Future<void> _deleteLocalImage(ClothingItem? item) async {
    final directory = await getApplicationDocumentsDirectory();
    final candidates = <String>{
      '${directory.path}/wardrobe_items/${item?.id ?? ''}.jpg'
    };
    final localImagePath = item?.localImagePath;
    if (localImagePath != null && localImagePath.isNotEmpty) {
      candidates.add(localImagePath);
    }

    for (final path in candidates) {
      if (!path.toLowerCase().endsWith('.jpg')) continue;
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  String _categoryAlias(String value) {
    switch (_normalize(value)) {
      case 'shirt':
      case 'tshirt':
      case 'tee':
        return 'top';
      case 'pants':
      case 'trousers':
      case 'jeans':
      case 'shorts':
      case 'skirt':
        return 'bottom';
      case 'shoe':
      case 'sneaker':
      case 'boots':
      case 'boot':
        return 'shoes';
      case 'accessory':
      case 'bag':
      case 'hat':
      case 'belt':
      case 'jewelry':
        return 'accessory';
      default:
        return _normalize(value);
    }
  }
}
