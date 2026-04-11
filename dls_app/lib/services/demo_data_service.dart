import 'package:cloud_firestore/cloud_firestore.dart';

class DemoSeedResult {
  DemoSeedResult({
    required this.itemsCreated,
    required this.historyCreated,
    required this.eventsCreated,
  });

  final int itemsCreated;
  final int historyCreated;
  final int eventsCreated;
}

class DemoDataService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<DemoSeedResult> seedForUser(String userId) async {
    final now = DateTime.now();

    final existingDemo = await _firestore
        .collection('clothing_items')
        .where('user_id', isEqualTo: userId)
        .where('is_demo', isEqualTo: true)
        .limit(1)
        .get();

    if (existingDemo.docs.isNotEmpty) {
      return DemoSeedResult(itemsCreated: 0, historyCreated: 0, eventsCreated: 0);
    }

    final wardrobeItems = <Map<String, dynamic>>[
      {
        'category': 'shirt',
        'color': 'white',
        'style_tags': ['minimal', 'smart_casual'],
        'status': 'clean',
        'image_url': 'https://images.unsplash.com/photo-1602810318383-e386cc2a3ccf?auto=format&fit=crop&w=900&q=80',
      },
      {
        'category': 'pants',
        'color': 'black',
        'style_tags': ['minimal', 'formal'],
        'status': 'clean',
        'image_url': 'https://images.unsplash.com/photo-1624378439575-d8705ad7ae80?auto=format&fit=crop&w=900&q=80',
      },
      {
        'category': 'shoes',
        'color': 'brown',
        'style_tags': ['formal'],
        'status': 'clean',
        'image_url': 'https://images.unsplash.com/photo-1614252369475-531eba835eb1?auto=format&fit=crop&w=900&q=80',
      },
      {
        'category': 'outerwear',
        'color': 'olive',
        'style_tags': ['streetwear', 'smart_casual'],
        'status': 'clean',
        'image_url': 'https://images.unsplash.com/photo-1521223890158-f9f7c3d5d504?auto=format&fit=crop&w=900&q=80',
      },
      {
        'category': 'accessory',
        'color': 'gold',
        'style_tags': ['soft_life'],
        'status': 'clean',
        'image_url': 'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?auto=format&fit=crop&w=900&q=80',
      },
      {
        'category': 'shirt',
        'color': 'blue',
        'style_tags': ['casual', 'streetwear'],
        'status': 'in_wash',
        'image_url': 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?auto=format&fit=crop&w=900&q=80',
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
        'user_id': userId,
        'is_demo': true,
        'createdAt': Timestamp.fromDate(createdAt),
        'created_at': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(createdAt),
      });
    }

    for (var i = 0; i < outfitHistory.length; i++) {
      final doc = _firestore.collection('outfit_history').doc();
      final generatedAt = now.subtract(Duration(days: i + 1));
      batch.set(doc, {
        ...outfitHistory[i],
        'user_id': userId,
        'is_demo': true,
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
}
