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

  test('every persona has a profile whose email maps back to it', () {
    for (final persona in personas) {
      final profile = kPersonaProfiles[persona.id];
      expect(profile, isNotNull, reason: persona.id);
      expect(personaIdForEmail(profile!.email), persona.id);
    }
    expect(personaIdForEmail('someone@gmail.com'), isNull);
  });

  test('persona write plan writes a complete onboarding profile', () {
    final plan = buildPersonaWrites(
      persona: personas.first,
      userId: 'uid-1',
      now: DateTime(2026, 10, 10),
      newId: () => 'x',
    );
    final user = plan.writes.singleWhere((w) => w.collection == 'users');
    expect(user.id, 'uid-1');
    expect(user.merge, isTrue);
    for (final key in [
      'email',
      'displayName',
      'firstName',
      'lastName',
      'birthdate',
      'age',
      'gender',
      'stylePreferences',
      'createdAt',
    ]) {
      expect(user.data.containsKey(key), isTrue, reason: key);
    }
  });

  test('persona profile uses onboarding style labels', () {
    final persona = personas.singleWhere((p) => p.id == 'man_street');
    final plan = buildPersonaWrites(
      persona: persona,
      userId: 'uid-1',
      now: DateTime(2026, 10, 10),
      newId: () => 'x',
    );
    final user = plan.writes.singleWhere((w) => w.collection == 'users');
    expect(user.data['stylePreferences'], ['Casual', 'Street Flex']);
    expect(user.data['style_dna'], 'Casual');
  });

  test('re-seeding an existing profile keeps its original createdAt', () {
    final plan = buildPersonaWrites(
      persona: personas.first,
      userId: 'uid-1',
      now: DateTime(2026, 10, 10),
      newId: () => 'x',
      isNewProfile: false,
    );
    final user = plan.writes.singleWhere((w) => w.collection == 'users');
    expect(user.data.containsKey('createdAt'), isFalse);
  });

  test('ageOn counts whole years and respects the birthday', () {
    expect(ageOn(DateTime(1994, 3, 12), DateTime(2026, 10, 10)), 32);
    expect(ageOn(DateTime(1994, 3, 12), DateTime(2026, 3, 11)), 31);
  });
}
