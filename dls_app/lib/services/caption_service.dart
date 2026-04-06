import 'dart:math';

class CaptionService {
  static const List<String> _templates = [
    'Clean Drip vibes for a {occasion} fire.',
    'Sharp njalo. {mood} mode activated.',
    '{weather} look, {occasion} ready.',
  ];

  final Random _random = Random();

  String generate({
    required String occasion,
    required String mood,
    required String weather,
  }) {
    final template = _templates[_random.nextInt(_templates.length)];
    return template
        .replaceAll('{occasion}', occasion)
        .replaceAll('{mood}', mood)
        .replaceAll('{weather}', weather);
  }
}
