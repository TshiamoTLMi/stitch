import 'dart:io';
import 'dart:typed_data';

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
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw Exception('Unable to decode image for compression.');
    }

    final resized = decoded.width > maxWidth
        ? img.copyResize(
            decoded,
            width: maxWidth,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    final compressed = Uint8List.fromList(
      img.encodeJpg(resized, quality: jpegQuality),
    );

    return CompressionResult(
      bytes: compressed,
      width: resized.width,
      height: resized.height,
      format: 'jpeg',
    );
  }
}
