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
  final Map<String, List<OutfitHistoryEntry>> _localEntriesByUser =
      <String, List<OutfitHistoryEntry>>{};

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
    final localEntry = OutfitHistoryEntry(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      occasion: occasion,
      mood: mood,
      weather: weather,
      score: result.score,
      generatedAt: DateTime.now(),
      caption: caption,
    );

    final localList = _localEntriesByUser.putIfAbsent(userId, () => <OutfitHistoryEntry>[]);
    localList.insert(0, localEntry);

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

  Stream<List<OutfitHistoryEntry>> streamRecentHistory(String userId, {int limit = 5}) async* {
    List<OutfitHistoryEntry> buildMergedList(List<OutfitHistoryEntry> remote) {
      final local = _localEntriesByUser[userId] ?? <OutfitHistoryEntry>[];
      final merged = <OutfitHistoryEntry>[...local, ...remote]
        ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

      if (merged.length <= limit) {
        return merged;
      }
      return merged.take(limit).toList();
    }

    yield buildMergedList(<OutfitHistoryEntry>[]);

    try {
      await for (final snapshot in _collection.where('user_id', isEqualTo: userId).snapshots()) {
        final remoteEntries = snapshot.docs.map(OutfitHistoryEntry.fromDoc).toList();
        yield buildMergedList(remoteEntries);
      }
    } catch (_) {
      yield buildMergedList(<OutfitHistoryEntry>[]);
    }
  }
}
