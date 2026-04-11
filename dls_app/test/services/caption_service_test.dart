import 'package:dls_app/services/caption_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = CaptionService();

  test('caption replaces all template placeholders', () {
    final caption = service.generate(
      occasion: 'Date Night',
      mood: 'Clean Drip',
      weather: 'Rainy',
    );

    expect(caption, isNot(contains('{occasion}')));
    expect(caption, isNot(contains('{mood}')));
    expect(caption, isNot(contains('{weather}')));
  });

  test('caption contains at least one runtime input value', () {
    final caption = service.generate(
      occasion: 'Work',
      mood: 'Minimal',
      weather: 'Cold',
    );

    final hasInput =
        caption.contains('Work') || caption.contains('Minimal') || caption.contains('Cold');

    expect(hasInput, isTrue);
  });
}
