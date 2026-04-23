import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/clothing_item.dart';
import '../models/outfit_result.dart';

enum OutfitLlmProvider { gemini, deepseek }

class OutfitLlmInsight {
  const OutfitLlmInsight({
    required this.caption,
    required this.reasoning,
  });

  final String caption;
  final List<String> reasoning;
}

class OutfitLlmService {
  static const String _providerRaw = String.fromEnvironment(
    'DLS_LLM_PROVIDER',
    defaultValue: 'gemini',
  );
  static const String _apiKey = String.fromEnvironment('DLS_LLM_API_KEY');
  static const String _modelRaw = String.fromEnvironment('DLS_LLM_MODEL', defaultValue: '');

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  OutfitLlmProvider get provider {
    final normalized = _providerRaw.trim().toLowerCase();
    if (normalized == 'deepseek') {
      return OutfitLlmProvider.deepseek;
    }
    return OutfitLlmProvider.gemini;
  }

  String get model {
    if (_modelRaw.trim().isNotEmpty) {
      return _modelRaw.trim();
    }
    return provider == OutfitLlmProvider.deepseek ? 'deepseek-chat' : 'gemini-1.5-flash';
  }

  Future<OutfitLlmInsight?> enhanceOutfit({
    required List<ClothingItem> wardrobe,
    required OutfitResult result,
    required String occasion,
    required String mood,
    required String weather,
  }) async {
    if (!isConfigured || !result.isValid) {
      return null;
    }

    try {
      switch (provider) {
        case OutfitLlmProvider.gemini:
          return _callGemini(
            wardrobe: wardrobe,
            result: result,
            occasion: occasion,
            mood: mood,
            weather: weather,
          );
        case OutfitLlmProvider.deepseek:
          return _callDeepSeek(
            wardrobe: wardrobe,
            result: result,
            occasion: occasion,
            mood: mood,
            weather: weather,
          );
      }
    } catch (_) {
      return null;
    }
  }

  Future<OutfitLlmInsight?> _callGemini({
    required List<ClothingItem> wardrobe,
    required OutfitResult result,
    required String occasion,
    required String mood,
    required String weather,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
    );

    final response = await http.post(
      uri,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'contents': [
          {
            'parts': [
              {'text': _buildPrompt(wardrobe: wardrobe, result: result, occasion: occasion, mood: mood, weather: weather)},
            ],
          }
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = (data['candidates'] as List?) ?? const <dynamic>[];
    if (candidates.isEmpty) {
      return null;
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = (content?['parts'] as List?) ?? const <dynamic>[];
    final text = (parts.isNotEmpty ? parts.first['text'] : null) as String?;
    if (text == null || text.trim().isEmpty) {
      return null;
    }

    return _parseInsightFromText(text);
  }

  Future<OutfitLlmInsight?> _callDeepSeek({
    required List<ClothingItem> wardrobe,
    required OutfitResult result,
    required String occasion,
    required String mood,
    required String weather,
  }) async {
    final uri = Uri.parse('https://api.deepseek.com/chat/completions');

    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(<String, dynamic>{
        'model': model,
        'messages': [
          {'role': 'system', 'content': 'You are a fashion stylist for a mobile app. Return strict JSON only.'},
          {
            'role': 'user',
            'content': _buildPrompt(wardrobe: wardrobe, result: result, occasion: occasion, mood: mood, weather: weather),
          },
        ],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = (data['choices'] as List?) ?? const <dynamic>[];
    if (choices.isEmpty) {
      return null;
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final text = message?['content'] as String?;
    if (text == null || text.trim().isEmpty) {
      return null;
    }

    return _parseInsightFromText(text);
  }

  OutfitLlmInsight? _parseInsightFromText(String text) {
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final maybeJson = text.substring(start, end + 1);
        try {
          parsed = jsonDecode(maybeJson) as Map<String, dynamic>;
        } catch (_) {
          parsed = null;
        }
      }
    }

    if (parsed == null) {
      return null;
    }

    final caption = (parsed['caption'] as String?)?.trim();
    final reasoningRaw = parsed['reasoning'];
    final reasoning = reasoningRaw is List
        ? reasoningRaw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).take(4).toList()
        : <String>[];

    if (caption == null || caption.isEmpty) {
      return null;
    }

    return OutfitLlmInsight(caption: caption, reasoning: reasoning);
  }

  String _buildPrompt({
    required List<ClothingItem> wardrobe,
    required OutfitResult result,
    required String occasion,
    required String mood,
    required String weather,
  }) {
    String itemSummary(ClothingItem? item) {
      if (item == null) {
        return '-';
      }
      final tags = item.styleTags.join(', ');
      return '${item.subcategory} | color=${item.color} | type=${item.categoryType} | tags=$tags';
    }

    final cleanCount = wardrobe.where((item) => item.isClean).length;

    return '''
You are styling an outfit for a South African fashion app.
Context:
- Occasion: $occasion
- Mood: $mood
- Weather: $weather
- Clean wardrobe items available: $cleanCount

Selected outfit:
- Top: ${itemSummary(result.top)}
- Bottom: ${itemSummary(result.bottom)}
- Shoes: ${itemSummary(result.shoes)}
- Accessory: ${itemSummary(result.accessory)}

Return strict JSON only with this exact schema:
{
  "caption": "short, punchy caption under 110 chars",
  "reasoning": ["max 4 concise bullets, each under 90 chars"]
}
''';
  }
}
