import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../core/constants/wardrobe_taxonomy.dart';

class DemoSeedResult {
  DemoSeedResult({
    required this.itemsCreated,
    required this.historyCreated,
    required this.eventsCreated,
    this.itemsRepaired = 0,
    this.historyRepaired = 0,
    this.eventsRepaired = 0,
  });

  final int itemsCreated;
  final int historyCreated;
  final int eventsCreated;
  final int itemsRepaired;
  final int historyRepaired;
  final int eventsRepaired;
}

/// Seeds a small demo dataset for an existing signed-in user.
///
/// Deprecated (Sprint 9): superseded by the bundled seed wardrobe
/// (`assets/seed/wardrobe_seed.json`) and the upcoming `MockWardrobeSeeder`.
/// All hardcoded third-party (Unsplash) image URLs have been removed; demo
/// items now reference local bundled CC0 assets under `assets/seed/images/`.
class DemoDataService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Gated on `kDebugMode` or `--dart-define=DLS_DEMO_MODE=true`, matching
  /// `MockWardrobeSeeder`. A release build must never write synthetic wardrobe
  /// data into a real user's Firestore account.
  static const bool demoEnvFlag = bool.fromEnvironment('DLS_DEMO_MODE');
  static bool get isDemoEnabled => kDebugMode || demoEnvFlag;

  Future<DemoSeedResult> seedForUser(String userId) async {
    if (!isDemoEnabled) {
      return DemoSeedResult(
        itemsCreated: 0,
        historyCreated: 0,
        eventsCreated: 0,
      );
    }

    final now = DateTime.now();

    final existingLegacyDemo = await _firestore
        .collection('clothing_items')
        .where('user_id', isEqualTo: userId)
        .where('is_demo', isEqualTo: true)
        .limit(1)
        .get();
    final existingNewDemo = await _firestore
        .collection('clothing_items')
        .where('userId', isEqualTo: userId)
        .where('is_demo', isEqualTo: true)
        .limit(1)
        .get();

    if (existingLegacyDemo.docs.isNotEmpty || existingNewDemo.docs.isNotEmpty) {
      return _repairExistingDemoData(userId, now);
    }

    final wardrobeItems = <Map<String, dynamic>>[
      {
        'parentCategory': 'Tops',
        'subcategory': 'Button-down shirts',
        'categoryType': 'top',
        'color': 'white',
        'colorGroup': deriveColorGroup('white'),
        'styleTags': ['smart_casual', 'formal'],
        'season': 'All Season',
        'status': 'clean',
        'gender': 'Unisex',
        'image_url': 'assets/seed/images/tops-blouse.jpg',
      },
      {
        'parentCategory': 'Bottoms',
        'subcategory': 'Trousers',
        'categoryType': 'bottom',
        'fit': 'Regular',
        'color': 'black',
        'colorGroup': deriveColorGroup('black'),
        'styleTags': ['formal', 'smart_casual'],
        'season': 'All Season',
        'status': 'clean',
        'gender': 'Unisex',
        'image_url': 'assets/seed/images/bottoms-breeches.jpg',
      },
      {
        'parentCategory': 'Footwear',
        'subcategory': 'Loafers',
        'categoryType': 'shoes',
        'color': 'brown',
        'colorGroup': deriveColorGroup('brown'),
        'styleTags': ['formal', 'smart_casual'],
        'season': 'All Season',
        'status': 'clean',
        'gender': 'Unisex',
        'image_url': 'assets/seed/images/footwear-bluchers.jpg',
      },
      {
        'parentCategory': 'Outerwear',
        'subcategory': 'Blazers',
        'categoryType': 'top',
        'fit': 'Oversized',
        'color': 'olive',
        'colorGroup': deriveColorGroup('olive'),
        'styleTags': ['streetwear', 'smart_casual'],
        'season': 'Winter',
        'status': 'clean',
        'gender': 'Unisex',
        'image_url': 'assets/seed/images/outerwear-spencer.jpg',
      },
      {
        'parentCategory': 'Accessories',
        'subcategory': 'Jewelry',
        'categoryType': 'accessory',
        'color': 'yellow',
        'colorGroup': deriveColorGroup('yellow'),
        'styleTags': ['formal', 'smart_casual'],
        'season': 'All Season',
        'status': 'clean',
        'gender': 'Unisex',
        'image_url': 'assets/seed/images/accessories-amulet.jpg',
      },
      {
        'parentCategory': 'Tops',
        'subcategory': 'T-shirts',
        'categoryType': 'top',
        'color': 'blue',
        'colorGroup': deriveColorGroup('blue'),
        'styleTags': ['casual', 'streetwear'],
        'season': 'Summer',
        'status': 'in_wash',
        'gender': 'Unisex',
        'image_url': 'assets/seed/images/tops-t-shirt.jpg',
      },
    ];

    final outfitHistory = <Map<String, dynamic>>[
      {
        'occasion': 'Work',
        'mood': 'Minimal',
        'weather': 'Sunny',
        'caption': 'Boardroom sharp, township bold.',
        'score': 87,
      },
      {
        'occasion': 'Date',
        'mood': 'Soft Life',
        'weather': 'Cold',
        'caption': 'Golden-hour confidence with clean tailoring.',
        'score': 91,
      },
      {
        'occasion': 'Groove',
        'mood': 'Street Flex',
        'weather': 'Hot',
        'caption': 'Night move uniform: effortless and loud.',
        'score': 84,
      },
    ];

    final events = <Map<String, dynamic>>[
      {
        'name': 'Client Pitch',
        'occasion': 'Work',
        'daysFromNow': 2,
        'recommended_outfits': ['Score 88: shirt + pants + shoes'],
      },
      {
        'name': 'Saturday Groove',
        'occasion': 'Groove',
        'daysFromNow': 4,
        'recommended_outfits': ['Score 84: shirt + pants + shoes'],
      },
      {
        'name': 'Family Event',
        'occasion': 'Event',
        'daysFromNow': 7,
        'recommended_outfits': ['Score 86: shirt + pants + shoes'],
      },
    ];

    final batch = _firestore.batch();

    for (var i = 0; i < wardrobeItems.length; i++) {
      final doc = _firestore.collection('clothing_items').doc();
      final createdAt = now.subtract(Duration(days: i + 1));
      final imageUrl = wardrobeItems[i]['image_url'];
      batch.set(doc, {
        ...wardrobeItems[i],
        'id': doc.id,
        'imageUrl': imageUrl,
        'image_url': imageUrl,
        'userId': userId,
        'user_id': userId,
        'is_demo': true,
        'createdAt': Timestamp.fromDate(createdAt),
        'created_at': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(createdAt),

        // Legacy compatibility fields.
        'category': wardrobeItems[i]['subcategory'],
        'style_tags': wardrobeItems[i]['styleTags'],
      });
    }

    for (var i = 0; i < outfitHistory.length; i++) {
      final doc = _firestore.collection('outfit_history').doc();
      final generatedAt = now.subtract(Duration(days: i + 1));
      batch.set(doc, {
        ...outfitHistory[i],
        'userId': userId,
        'user_id': userId,
        'is_demo': true,
        'generatedAt': Timestamp.fromDate(generatedAt),
        'generated_at': Timestamp.fromDate(generatedAt),
        'outfit': {
          'top_id': 'demo_top',
          'bottom_id': 'demo_bottom',
          'shoes_id': 'demo_shoes',
          'accessory_id': 'demo_accessory',
          'score': (outfitHistory[i]['score'] as int),
          'reasoning': ['Demo seed outfit for sprint testing'],
        },
      });
    }

    for (final event in events) {
      final doc = _firestore.collection('events').doc();
      batch.set(doc, {
        'userId': userId,
        'user_id': userId,
        'name': event['name'],
        'occasion': event['occasion'],
        'recommended_outfits': event['recommended_outfits'],
        'is_demo': true,
        'date': Timestamp.fromDate(
          now.add(Duration(days: event['daysFromNow'] as int)),
        ),
      });
    }

    final userDoc = _firestore.collection('users').doc(userId);
    batch.set(userDoc, {
      'style_dna': 'smart_casual',
      'last_seeded_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    final auditDoc = _firestore.collection('audit_events').doc();
    batch.set(auditDoc, {
      'user_id': userId,
      'is_demo': true,
      'type': 'demo_seed',
      'sprint': 6,
      'message': 'Demo data seeded for sprint validation.',
      'created_at': Timestamp.fromDate(now),
    });

    await batch.commit();

    return DemoSeedResult(
      itemsCreated: wardrobeItems.length,
      historyCreated: outfitHistory.length,
      eventsCreated: events.length,
    );
  }

  Future<DemoSeedResult> _repairExistingDemoData(String userId, DateTime now) async {
    final clothingLegacy = await _firestore
        .collection('clothing_items')
        .where('user_id', isEqualTo: userId)
        .where('is_demo', isEqualTo: true)
        .get();
    final clothingNew = await _firestore
        .collection('clothing_items')
        .where('userId', isEqualTo: userId)
        .where('is_demo', isEqualTo: true)
        .get();
    final history = await _firestore
        .collection('outfit_history')
        .where('user_id', isEqualTo: userId)
        .where('is_demo', isEqualTo: true)
        .get();
    final events = await _firestore
        .collection('events')
        .where('user_id', isEqualTo: userId)
        .where('is_demo', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    final clothingDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final doc in clothingLegacy.docs) doc.id: doc,
      for (final doc in clothingNew.docs) doc.id: doc,
    }.values;

    var repairedItems = 0;
    for (final doc in clothingDocs) {
      final data = doc.data();
      final category = ((data['category'] as String?) ?? '').toLowerCase();
      final imageUrl = (data['imageUrl'] as String?) ?? (data['image_url'] as String?) ?? '';
      final normalized = _normalizeLegacyCategory(category);
      batch.set(doc.reference, {
        'userId': userId,
        'parentCategory': normalized['parentCategory'],
        'subcategory': normalized['subcategory'],
        'categoryType': normalized['categoryType'],
        if (normalized['fit'] != null) 'fit': normalized['fit'],
        'color': (data['color'] as String?) ?? 'black',
        'colorGroup': _mapColorGroup((data['color'] as String?) ?? 'black'),
        'styleTags': List<String>.from(
          data['styleTags'] as List? ?? data['style_tags'] as List? ?? const <String>[],
        ),
        'season': (data['season'] as String?) ?? 'All Season',
        'status': (data['status'] as String?) ?? 'clean',
        'gender': (data['gender'] as String?) ?? 'Unisex',
        'imageUrl': imageUrl,
        'image_url': imageUrl,
        'updatedAt': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      repairedItems++;
    }

    for (final doc in history.docs) {
      batch.set(doc.reference, {
        'userId': userId,
        'generatedAt': (doc.data()['generated_at'] as Timestamp?) ?? Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }

    for (final doc in events.docs) {
      batch.set(doc.reference, {
        'userId': userId,
      }, SetOptions(merge: true));
    }

    await batch.commit();

    return DemoSeedResult(
      itemsCreated: 0,
      historyCreated: 0,
      eventsCreated: 0,
      itemsRepaired: repairedItems,
      historyRepaired: history.docs.length,
      eventsRepaired: events.docs.length,
    );
  }

  Map<String, String?> _normalizeLegacyCategory(String category) {
    switch (category) {
      case 'pants':
      case 'trousers':
        return {
          'parentCategory': 'Bottoms',
          'subcategory': 'Trousers',
          'categoryType': 'bottom',
          'fit': 'Regular',
        };
      case 'shoes':
        return {
          'parentCategory': 'Footwear',
          'subcategory': 'Loafers',
          'categoryType': 'shoes',
          'fit': null,
        };
      case 'outerwear':
      case 'jacket':
        return {
          'parentCategory': 'Outerwear',
          'subcategory': 'Blazers',
          'categoryType': 'top',
          'fit': 'Oversized',
        };
      case 'accessory':
      case 'accessories':
        return {
          'parentCategory': 'Accessories',
          'subcategory': 'Jewelry',
          'categoryType': 'accessory',
          'fit': null,
        };
      default:
        return {
          'parentCategory': 'Tops',
          'subcategory': 'T-shirts',
          'categoryType': 'top',
          'fit': null,
        };
    }
  }

  String _mapColorGroup(String color) => deriveColorGroup(color);
}
