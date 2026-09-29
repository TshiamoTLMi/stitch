import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

class CompressionResult {
  CompressionResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String format;
}

/// Client-side photo compression for newly added clothing items.
///
/// Two limits are enforced, both on-device before anything is uploaded:
///  * **Dimensions** - the long edge is capped at 1080px (a 1080x1080 target).
///  * **Quality**    - JPEG at 80%, targeting well under 300 KB per item.
///
/// [QA TEST POINT] Upload compression
/// - Pick a 12 MP photo: upload completes and the stored file is < 300 KB.
/// - Check the Wardrobe grid on a device: thumbnails are sharp, not pixelated.
/// - Upload from Safari: the same limits apply (web uses the list-based path).
/// - Force-close mid-upload: no half-written file is left in app storage.
class ImageCompressionService {
  ImageCompressionService();

  /// Long-edge cap in pixels.
  static const int maxDimension = 1080;

  /// JPEG quality, 0-100. 80 keeps visible artefacts out of fabric textures.
  static const int jpegQuality = 80;

  /// Soft target for the encoded size of a single item, in bytes.
  static const int targetMaxBytes = 300 * 1024;

  Future<CompressionResult> compressImage(
    File file, {
    int maxWidth = 1080,
    int jpegQuality = 75,
  }) async {
    final inputBytes = await file.readAsBytes();
    return compressBytes(
      inputBytes,
      maxWidth: maxWidth,
      jpegQuality: jpegQuality,
    );
  }

  Future<CompressionResult> compressBytes(
    Uint8List inputBytes, {
    int maxWidth = 1080,
    int jpegQuality = 75,
  }) async {
    final compressedBytes = await FlutterImageCompress.compressWithList(
      inputBytes,
      minWidth: maxWidth,
      quality: jpegQuality,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes.isEmpty) {
      throw Exception('Unable to compress image.');
    }

    final decoded = img.decodeImage(compressedBytes);
    if (decoded == null) {
      throw Exception('Unable to decode image for compression.');
    }

    return CompressionResult(
      bytes: compressedBytes,
      width: decoded.width,
      height: decoded.height,
      format: 'jpeg',
    );
  }
}
