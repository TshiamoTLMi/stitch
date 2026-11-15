import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dls_app/core/constants/wardrobe_taxonomy.dart';
import 'package:dls_app/services/real_user_demo_seed_service.dart';

List<Map<String, dynamic>> _loadStarterItems() {
  final raw = File('assets/seed/starter_wardrobe.json').readAsStringSync();
  final doc = jsonDecode(raw) as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(doc['items'] as List);
}

void main() {
  final items = _loadStarterItems();

  test('starter wardrobe asset has a small, non-empty generic item set', () {
    expect(items, isNotEmpty);
    expect(items.length, lessThanOrEqualTo(15),
        reason: 'starter wardrobe should stay small, not a full closet');
  });

  test('every item image exists in the bundled assets', () {
    for (final item in items) {
      final path = item['localImagePath'] as String;
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('every item has a valid parentCategory/subcategory taxonomy pair', () {
    for (final item in items) {
      final parent = item['parentCategory'] as String;
      final sub = item['subcategory'] as String;
      expect(categoryTaxonomy.containsKey(parent), isTrue, reason: parent);
      expect(categoryTaxonomy[parent], contains(sub), reason: '$parent/$sub');
    }
  });

  test('buildStarterWrites tags every write is_demo:false, source:starter_seed, '
      'never the QA is_demo:true tag', () {
    var counter = 0;
    final writes = buildStarterWrites(
      items: items,
      userId: 'uid-1',
      now: DateTime(2026, 10, 10),
      newId: () => 'id-${counter++}',
    );

    expect(writes, hasLength(items.length));
    expect(writes.every((w) => w.collection == 'clothing_items'), isTrue);
    expect(writes.every((w) => w.data['is_demo'] == false), isTrue);
    expect(writes.every((w) => w.data['source'] == 'starter_seed'), isTrue);
    expect(writes.every((w) => w.data['userId'] == 'uid-1'), isTrue);
  });

  test('buildStarterWrites derives categoryType and colorGroup through the '
      'existing taxonomy helpers rather than hardcoding them', () {
    final writes = buildStarterWrites(
      items: items,
      userId: 'uid-1',
      now: DateTime(2026, 10, 10),
      newId: () => 'x',
    );

    for (var i = 0; i < writes.length; i++) {
      final item = items[i];
      final write = writes[i];
      expect(
        write.data['categoryType'],
        deriveCategoryType(
          parentCategory: item['parentCategory'] as String,
          subcategory: item['subcategory'] as String,
        ),
      );
      expect(
        write.data['colorGroup'],
        deriveColorGroup(item['color'] as String),
      );
    }
  });

  test('a Trousers item (which requiresFit) carries a fit value', () {
    final trousers =
        items.where((i) => i['subcategory'] == 'Trousers').toList();
    expect(trousers, isNotEmpty);
    for (final item in trousers) {
      expect(item['fit'], isNotNull);
    }
  });
}
