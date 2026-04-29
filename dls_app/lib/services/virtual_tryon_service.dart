import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/outfit_result.dart';

class VirtualTryOnService {
  static const String _endpoint = String.fromEnvironment('DLS_TRYON_ENDPOINT');
  static const String _apiKey = String.fromEnvironment('DLS_TRYON_API_KEY');

  VirtualTryOnService({
    http.Client? client,
    String? endpointOverride,
    String? apiKeyOverride,
    Duration? requestTimeout,
  })  : _client = client ?? http.Client(),
        _endpointOverride = endpointOverride,
        _apiKeyOverride = apiKeyOverride,
        _requestTimeout = requestTimeout ?? const Duration(seconds: 20);

  final http.Client _client;
  final String? _endpointOverride;
  final String? _apiKeyOverride;
  final Duration _requestTimeout;

  String get _resolvedEndpoint => (_endpointOverride ?? _endpoint).trim();
  String get _resolvedApiKey => (_apiKeyOverride ?? _apiKey).trim();

  bool get isConfigured => _resolvedEndpoint.isNotEmpty;

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
      final response = await _client
          .post(
        Uri.parse(_resolvedEndpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (_resolvedApiKey.isNotEmpty) 'Authorization': 'Bearer $_resolvedApiKey',
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
      )
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final imageUrl = _readImageUrl(data);
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        return null;
      }
      return imageUrl.trim();
    } catch (_) {
      return null;
    }
  }

  String? _readImageUrl(Map<String, dynamic> data) {
    final topLevel = _readString(data, <String>['imageUrl', 'image_url']);
    if (topLevel != null && topLevel.isNotEmpty) {
      return topLevel;
    }

    final resultMap = data['result'];
    if (resultMap is Map<String, dynamic>) {
      final nested = _readString(resultMap, <String>['imageUrl', 'image_url']);
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }
    return null;
  }

  String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
