import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import '../models/vision_analysis.dart';

abstract interface class VisionEngine {
  Future<VisionAnalysis> analyzeClothingItem(Uint8List imageBytes);
}

class GeminiVisionEngine implements VisionEngine {
  GeminiVisionEngine({
    http.Client? client,
    FirebaseRemoteConfig? remoteConfig,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _remoteConfig = remoteConfig,
        _apiKeyOverride = apiKey;

  static const _model = 'gemini-1.5-flash';
  static const _maxBytes = 200 * 1024;
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  final http.Client _client;
  final FirebaseRemoteConfig? _remoteConfig;
  final String? _apiKeyOverride;

  @override
  Future<VisionAnalysis> analyzeClothingItem(Uint8List imageBytes) async {
    try {
      final compressed = await _compressUnderLimit(imageBytes);
      if (compressed == null) {
        return const VisionAnalysis(error: 'compression_failed');
      }

      final apiKey = await _readApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return const VisionAnalysis(error: 'not_configured');
      }

      final response = await _client
          .post(
            Uri.parse('$_endpoint?key=$apiKey'),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'contents': <Map<String, dynamic>>[
                <String, dynamic>{
                  'parts': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'text':
                          '''Analyze this image for a wardrobe item. If it is a face, pet, person without a garment, or random object, return exactly {"error":"not_clothing"}. Otherwise return JSON only with parentCategory, subcategory, color, and fit. Use values compatible with a clothing closet.''',
                    },
                    <String, dynamic>{
                      'inline_data': <String, String>{
                        'mime_type': 'image/jpeg',
                        'data': base64Encode(compressed),
                      },
                    },
                  ],
                },
              ],
              'generationConfig': <String, dynamic>{
                'responseMimeType': 'application/json',
                'temperature': 0,
              },
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const VisionAnalysis(error: 'api_failed');
      }
      final text = _extractText(response.body);
      if (text == null) return const VisionAnalysis(error: 'invalid_response');
      final json = jsonDecode(text);
      return json is Map<String, dynamic>
          ? VisionAnalysis.fromJson(json)
          : const VisionAnalysis(error: 'invalid_response');
    } on TimeoutException {
      return const VisionAnalysis(error: 'timeout');
    } catch (_) {
      return const VisionAnalysis(error: 'api_failed');
    }
  }

  Future<Uint8List?> _compressUnderLimit(Uint8List source) async {
    var quality = 75;
    Uint8List? compressed;
    while (quality >= 25) {
      compressed = await FlutterImageCompress.compressWithList(
        source,
        minWidth: 1280,
        minHeight: 1280,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (compressed.length <= _maxBytes) return compressed;
      quality -= 10;
    }
    return null;
  }

  Future<String?> _readApiKey() async {
    final override = _apiKeyOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    try {
      final config = _remoteConfig ?? FirebaseRemoteConfig.instance;
      await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await config.fetchAndActivate().timeout(const Duration(seconds: 5));
      final key = config.getString('gemini_vision_api_key').trim();
      return key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  String? _extractText(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      final content = candidates.first['content'];
      if (content is! Map) return null;
      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) return null;
      final text = parts.first['text'];
      if (text is! String) return null;
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      return start >= 0 && end > start ? text.substring(start, end + 1) : text;
    } catch (_) {
      return null;
    }
  }
}
