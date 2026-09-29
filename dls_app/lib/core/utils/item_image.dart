import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../models/clothing_item.dart';

/// Resolves an image source, local-first.
///
/// Priority:
/// 1. [localPath] as a bundled asset (`assets/...`) -> [AssetImage]
/// 2. [localPath] as a file on disk -> [FileImage]
/// 3. [url] as a bundled asset path -> [AssetImage]
/// 4. [url] as a network URL -> [NetworkImage]
///
/// Returns null when there is no usable source.
ImageProvider? resolveImageSource({required String url, String? localPath}) {
  final local = localPath?.trim() ?? '';
  if (local.isNotEmpty) {
    if (local.startsWith('assets/')) return AssetImage(local);
    return FileImage(File(local));
  }

  final remote = url.trim();
  if (remote.isEmpty) return null;
  if (remote.startsWith('assets/')) return AssetImage(remote);
  return NetworkImage(remote);
}

/// Local-first [ImageProvider] for a wardrobe item: prefers the bundled seed
/// asset or local file over the network URL.
ImageProvider? resolveItemImage(ClothingItem item) =>
    resolveImageSource(url: item.imageUrl, localPath: item.localImagePath);
