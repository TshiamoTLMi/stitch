import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;

import '../models/enhanced_outfit.dart';
import '../models/outfit.dart';
import '../models/user_profile.dart';
import 'outfit_feedback_service.dart';

class AIStylist {
  AIStylist({
    http.Client? client,
    OutfitFeedbackService? feedbackService,
    FirebaseRemoteConfig? remoteConfig,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _feedbackService = feedbackService ?? OutfitFeedbackService(),
        _remoteConfig = remoteConfig,
        _apiKeyOverride = apiKey;

  static const endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const model = 'llama-3.3-70b-versatile';

  final http.Client _client;
  final OutfitFeedbackService _feedbackService;
  final FirebaseRemoteConfig? _remoteConfig;
  final String? _apiKeyOverride;

  Future<EnhancedOutfit> enhance(
    List<Outfit> candidates,
    UserProfile user,
    Map<String, dynamic> context,
  ) async {
    if (candidates.isEmpty) {
      throw StateError('AIStylist requires at least one outfit candidate.');
    }

    final fallback = EnhancedOutfit(
      outfit: candidates.first,
      reason: 'Using basic mode. AI stylist unavailable.',
      usedAi: false,
    );
    final cacheKey = _buildCacheKey(user.id, context);

    try {
      final cached = await _feedbackService.readCachedDecision(cacheKey);
      if (cached != null) return _applyDecision(candidates, cached);

      final apiKey = await _readApiKey();
      if (apiKey == null || apiKey.isEmpty) return fallback;

      final feedback =
          await _feedbackService.fetchRecentFeedback(user.id, limit: 10);
      final reserved = await _feedbackService.tryReserveAiCall(user.id);
      if (!reserved) return fallback;

      final decision = await _requestDecision(
        apiKey: apiKey,
        user: user,
        context: context,
        candidates: candidates,
        feedback: feedback,
      );
      if (decision == null) return fallback;

      await _feedbackService.writeCachedDecision(cacheKey, decision);
      return _applyDecision(candidates, decision);
    } catch (_) {
      return fallback;
    }
  }

  Future<Map<String, dynamic>?> _requestDecision({
    required String apiKey,
    required UserProfile user,
    required Map<String, dynamic> context,
    required List<Outfit> candidates,
    required List<Map<String, dynamic>> feedback,
  }) async {
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(<String, dynamic>{
            'model': model,
            'messages': <Map<String, String>>[
              <String, String>{
                'role': 'system',
                'content':
                    'You are a South African personal stylist. Return JSON only. Use light SA street lingo in the reason.',
              },
              <String, String>{
                'role': 'user',
                'content': _buildPrompt(user, context, candidates, feedback),
              },
            ],
            'temperature': 0.4,
            'response_format': <String, String>{'type': 'json_object'},
          }),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final message = choices.first['message'];
    if (message is! Map) return null;
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) return null;

    try {
      final parsed = jsonDecode(content);
      return parsed is Map<String, dynamic> ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  EnhancedOutfit _applyDecision(
      List<Outfit> candidates, Map<String, dynamic> decision) {
    final rawIndex = decision['chosenIndex'];
    final index =
        rawIndex is num ? rawIndex.toInt().clamp(0, candidates.length - 1) : 0;
    final reason = (decision['reason'] as String?)?.trim();
    final swap = (decision['swapSuggestion'] as String?)?.trim();
    return EnhancedOutfit(
      outfit: candidates[index],
      reason:
          reason == null || reason.isEmpty ? candidates[index].reason : reason,
      swapSuggestion: swap == null || swap.isEmpty ? null : swap,
    );
  }

  Future<String?> _readApiKey() async {
    if (_apiKeyOverride != null) return _apiKeyOverride.trim();
    try {
      final config = _remoteConfig ?? FirebaseRemoteConfig.instance;
      await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await config.fetchAndActivate().timeout(const Duration(seconds: 5));
      final key = config.getString('groq_api_key').trim();
      return key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  String _buildPrompt(
    UserProfile user,
    Map<String, dynamic> context,
    List<Outfit> candidates,
    List<Map<String, dynamic>> feedback,
  ) {
    final safeFeedback = feedback
        .map((record) => Map<String, dynamic>.from(record)..remove('timestamp'))
        .toList();
    return '''
User profile: ${jsonEncode(user.toJson())}
Context: ${jsonEncode(context)}
Candidates: ${jsonEncode(candidates.map((outfit) => outfit.toJson()).toList())}
Past preferences from the last 10 outfit corrections: ${jsonEncode(safeFeedback)}

Choose the best candidate without inventing wardrobe items. Return exactly:
{"chosenIndex": 0, "reason": "...", "swapSuggestion": "optional ..."}
''';
  }

  String _buildCacheKey(String userId, Map<String, dynamic> context) =>
      '$userId|${context['occasion'] ?? ''}|${context['mood'] ?? ''}|${context['weather'] ?? ''}';
}
