import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/outfit_result.dart';

class OutfitHistoryEntry {
  OutfitHistoryEntry({
    required this.id,
    required this.occasion,
    required this.mood,
    required this.weather,
    required this.score,
    required this.generatedAt,
    required this.caption,
  });

  final String id;
  final String occasion;
  final String mood;
  final String weather;
  final int score;
  final DateTime generatedAt;
  final String caption;

  factory OutfitHistoryEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return OutfitHistoryEntry(
      id: doc.id,
      occasion: (data['occasion'] as String?) ?? 'Unknown',
      mood: (data['mood'] as String?) ?? 'Unknown',
      weather: (data['weather'] as String?) ?? 'Unknown',
      score: (data['score'] as num?)?.toInt() ?? 0,
      generatedAt:
          (data['generated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      caption: (data['caption'] as String?) ?? '',
    );
  }
}

class OutfitHistoryService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('outfit_history');

  Future<void> saveGeneratedOutfit({
    required String userId,
    required String occasion,
    required String mood,
    required String weather,
    required String caption,
    required OutfitResult result,
  }) async {
    try {
      await _collection.add({
        'user_id': userId,
        'generated_at': Timestamp.fromDate(DateTime.now()),
        'occasion': occasion,
        'mood': mood,
        'weather': weather,
        'caption': caption,
        'score': result.score,
        'outfit': result.toJson(),
      });
    } catch (_) {
      // Firebase may be unavailable in demo mode.
    }
  }

  Stream<List<OutfitHistoryEntry>> streamRecentHistory(String userId, {int limit = 5}) {
    try {
      return _collection.where('user_id', isEqualTo: userId).snapshots().map((snapshot) {
        final entries = snapshot.docs.map(OutfitHistoryEntry.fromDoc).toList()
          ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
        if (entries.length <= limit) {
          return entries;
        }
        return entries.take(limit).toList();
      });
    } catch (_) {
      return Stream.value(<OutfitHistoryEntry>[]);
    }
  }
}
