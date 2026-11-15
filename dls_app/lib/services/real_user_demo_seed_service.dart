import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/constants/wardrobe_taxonomy.dart';
import 'demo_data_service.dart' show kSeedBatchLimit;
import 'persona_seed.dart' show PlannedWrite;

/// Asset holding a small, generic starter wardrobe for real new users -
/// distinct from `assets/seed/personas.json`, which is QA/demo-only test
/// fixture data gated behind [DemoDataService.isDemoEnabled] and tied to
/// four hardcoded persona accounts.
const String kStarterWardrobeAsset = 'assets/seed/starter_wardrobe.json';

/// Builds the Firestore writes for a real user's optional starter wardrobe,
/// without touching Firestore - mirrors `buildPersonaWrites`' pure
/// plan-builder shape so it is unit-testable the same way.
///
/// Every write is tagged `is_demo: false` / `source: 'starter_seed'` (never
/// `is_demo: true`), so these items are real wardrobe data: they persist
/// through the QA "Clear My Test Data" sweep (which only targets
/// `is_demo: true` docs) and count toward the user's own analytics.
List<PlannedWrite> buildStarterWrites({
  required List<Map<String, dynamic>> items,
  required String userId,
  required DateTime now,
  required String Function() newId,
}) {
  final writes = <PlannedWrite>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final id = newId();
    final parentCategory = item['parentCategory'] as String;
    final subcategory = item['subcategory'] as String;
    final color = item['color'] as String;
    final styleTags = List<String>.from(item['styleTags'] as List);
    final imageUrl = item['imageUrl'] as String;
    final createdAt = Timestamp.fromDate(now.subtract(Duration(minutes: i)));

    writes.add(PlannedWrite(
      collection: 'clothing_items',
      id: id,
      data: {
        'id': id,
        'parentCategory': parentCategory,
        'subcategory': subcategory,
        'categoryType': deriveCategoryType(
          parentCategory: parentCategory,
          subcategory: subcategory,
        ),
        if (item['fit'] != null) 'fit': item['fit'],
        'color': color,
        'colorGroup': deriveColorGroup(color),
        'styleTags': styleTags,
        'season': item['season'],
        'status': item['status'],
        'gender': item['gender'],
        'imageUrl': imageUrl,
        'localImagePath': item['localImagePath'],
        'userId': userId,
        'user_id': userId,
        'createdAt': createdAt,
        'created_at': createdAt,
        'updatedAt': createdAt,
        'updated_at': createdAt,
        'image_url': imageUrl,
        'category': subcategory,
        'style_tags': styleTags,
        'is_demo': false,
        'source': 'starter_seed',
      },
    ));
  }
  return writes;
}

/// Seeds a small, generic starter wardrobe for a real user who chose "Load
/// Demo Wardrobe" during onboarding's guided first action - so they never
/// land on an empty Closet tab. Unlike [DemoDataService], this is NOT gated
/// to debug builds: it must work for real users in a release build.
class RealUserDemoSeedService {
  RealUserDemoSeedService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> loadStarterItems() async {
    final raw = await _bundle.loadString(kStarterWardrobeAsset);
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(doc['items'] as List);
  }

  /// Writes the starter wardrobe for [userId]. Safe to call even if the user
  /// already has items - it only adds, it never clears existing wardrobe
  /// data (unlike persona re-seeding, which replaces).
  Future<int> seedForUser(String userId) async {
    final items = await loadStarterItems();
    final writes = buildStarterWrites(
      items: items,
      userId: userId,
      now: DateTime.now(),
      newId: () => _firestore.collection('clothing_items').doc().id,
    );

    for (var start = 0; start < writes.length; start += kSeedBatchLimit) {
      final batch = _firestore.batch();
      for (final write in writes.skip(start).take(kSeedBatchLimit)) {
        batch.set(
          _firestore.collection(write.collection).doc(write.id),
          write.data,
          SetOptions(merge: write.merge),
        );
      }
      await batch.commit();
    }

    return writes.length;
  }
}
