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

class ImageCompressionService {
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
