import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dls_app/services/persona_seed.dart';

const int kMinClosetItems = 120;
const int kMinUnisexItems = 8;

void main() {
  final personas = parsePersonas(
    File('assets/seed/personas.json').readAsStringSync(),
  );

  test('generated file holds the four test personas', () {
    expect(personas.map((p) => p.id), hasLength(4));
  });

  test('every persona has at least 120 closet items', () {
    for (final persona in personas) {
      expect(
        persona.items.length,
        greaterThanOrEqualTo(kMinClosetItems),
        reason: persona.id,
      );
    }
  });

  test('every persona has at least 8 unisex items', () {
    for (final persona in personas) {
      final unisex = persona.items.where((i) => i['gender'] == 'Unisex');
      expect(unisex.length, greaterThanOrEqualTo(kMinUnisexItems),
          reason: persona.id);
    }
  });

  test('every item image exists in the bundled assets', () {
    for (final persona in personas) {
      for (final item in persona.items) {
        final path = item['localImagePath'] as String;
        expect(File(path).existsSync(), isTrue, reason: '${persona.id}: $path');
      }
    }
  });

  test('persona write plan covers the full closet with is_demo tags', () {
    var counter = 0;
    for (final persona in personas) {
      final plan = buildPersonaWrites(
        persona: persona,
        userId: 'test-user',
        now: DateTime(2026, 10, 10),
        newId: () => 'id-${counter++}',
      );
      final itemWrites =
          plan.writes.where((w) => w.collection == 'clothing_items').toList();

      expect(plan.itemCount, greaterThanOrEqualTo(kMinClosetItems),
          reason: persona.id);
      expect(itemWrites, hasLength(plan.itemCount), reason: persona.id);
      expect(
        itemWrites.every((w) => w.data['is_demo'] == true),
        isTrue,
        reason: persona.id,
      );
    }
  });
}
