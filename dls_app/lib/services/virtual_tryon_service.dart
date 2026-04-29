import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/outfit_result.dart';

class VirtualTryOnService {
  static const String _endpoint = String.fromEnvironment('DLS_TRYON_ENDPOINT');
  static const String _apiKey = String.fromEnvironment('DLS_TRYON_API_KEY');

  bool get isConfigured => _endpoint.trim().isNotEmpty;

  Future<String?> generateTryOnImage({
    required OutfitResult result,
    String? userPhotoUrl,
    String? mood,
    String? occasion,
    String? weather,
  }) async {
    if (!isConfigured || !result.isValid) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (_apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${_apiKey.trim()}',
        },
        body: jsonEncode(<String, dynamic>{
          'user_photo_url': userPhotoUrl,
          'occasion': occasion,
          'mood': mood,
          'weather': weather,
          'items': {
            'top': result.top?.imageUrl,
            'bottom': result.bottom?.imageUrl,
            'shoes': result.shoes?.imageUrl,
            'accessory': result.accessory?.imageUrl,
          },
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final imageUrl =
          (data['imageUrl'] as String?) ??
          (data['image_url'] as String?) ??
          (data['result'] as Map<String, dynamic>?)?['imageUrl'] as String?;
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        return null;
      }
      return imageUrl.trim();
    } catch (_) {
      return null;
    }
  }
}
