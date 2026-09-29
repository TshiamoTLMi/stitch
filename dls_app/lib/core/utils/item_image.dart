import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
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
    // Web has no app-owned file system, so a bare on-disk path is unusable.
    if (kIsWeb) return null;
    return FileImage(File(local));
  }

  final remote = url.trim();
  if (remote.isEmpty) return null;
  if (remote.startsWith('assets/')) return AssetImage(remote);
  return NetworkImage(remote);
}

/// Local-first [ImageProvider] for a wardrobe item: prefers the bundled seed
/// asset or local file over the network URL.
///
/// [QA TEST POINT] Image fallbacks
/// - A seed item (`assets/seed/images/...`) renders offline with no network.
/// - A deleted local file falls back to the Storage URL rather than a crash.
/// - On web, an on-disk `localImagePath` is unusable and resolves to null so
///   the caller can show a placeholder instead of throwing.
///
/// [QA TEST POINT] Memory footprint
/// Decoding is wrapped in [ResizeImage] at 240px so a 332-item wardrobe never
/// holds full-resolution bitmaps in the image cache.
ImageProvider? resolveItemImage(ClothingItem item) =>
    _bounded(resolveImageSource(url: item.imageUrl, localPath: item.localImagePath));

/// Caps the decode size of a resolved provider to keep memory flat.
///
/// A raw [AssetImage] of a 1080px photo decoded at full size is ~4.6 MB; at
/// 240px it is ~230 KB. Only assets are bounded -- `FileImage`/`NetworkImage`
/// are left alone because callers often request an explicit size themselves.
ImageProvider? _bounded(ImageProvider? provider) {
  if (provider is AssetImage) {
    return ResizeImage(
      provider,
      width: 240,
      height: 240,
      policy: ResizeImagePolicy.fit,
    );
  }
  return provider;
}
