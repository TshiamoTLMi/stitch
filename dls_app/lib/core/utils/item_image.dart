import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../models/clothing_item.dart';

/// Resolves the image source for a wardrobe item, local-first.
///
/// Priority:
/// 1. `localImagePath` that is a bundled asset (`assets/...`) -> [AssetImage]
/// 2. `localImagePath` that is a file on disk -> [FileImage]
/// 3. `imageUrl` that is a bundled asset path -> [AssetImage]
/// 4. `imageUrl` as a network URL -> [NetworkImage]
///
/// Returns null when the item has no usable image source.
ImageProvider? resolveItemImage(ClothingItem item) {
  final localPath = item.localImagePath?.trim() ?? '';
  if (localPath.isNotEmpty) {
    if (localPath.startsWith('assets/')) return AssetImage(localPath);
    return FileImage(File(localPath));
  }

  final url = item.imageUrl.trim();
  if (url.isEmpty) return null;
  if (url.startsWith('assets/')) return AssetImage(url);
  return NetworkImage(url);
}
