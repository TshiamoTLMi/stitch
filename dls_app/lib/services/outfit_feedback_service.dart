import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/outfit.dart';

class OutfitFeedbackService {
  OutfitFeedbackService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _feedbackCollection =>
      _firestore.collection('outfit_feedback');

  Future<void> saveFeedback({
    required String userId,
    required Outfit generatedOutfit,
    required Map<String, dynamic> userFinalOutfit,
    required String reason,
    required String occasion,
    required String mood,
  }) async {
    await _feedbackCollection.add(<String, dynamic>{
      'userId': userId,
      'generatedOutfit': generatedOutfit.toJson(),
      'userFinalOutfit': userFinalOutfit,
      'reason': reason,
      'occasion': occasion,
      'mood': mood,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchRecentFeedback(
    String userId, {
    int limit = 10,
  }) async {
    final snapshot = await _feedbackCollection
        .where('userId', isEqualTo: userId)
        .limit(50)
        .get();
    final records = snapshot.docs
        .map((doc) => <String, dynamic>{
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
    records.sort((a, b) =>
        _timestamp(b['timestamp']).compareTo(_timestamp(a['timestamp'])));
    return records.take(limit).toList(growable: false);
  }

  Future<bool> tryReserveAiCall(String userId, {int dailyLimit = 20}) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final today = _dayKey(DateTime.now().toUtc());
      return _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data() ?? <String, dynamic>{};
        final storedDay = data['aiCallsDay'] as String?;
        final currentCount = storedDay == today
            ? (data['aiCallsCount'] as num?)?.toInt() ?? 0
            : 0;
        if (currentCount >= dailyLimit) return false;
        transaction.set(
          userRef,
          <String, dynamic>{
            'aiCallsDay': today,
            'aiCallsCount': currentCount + 1
          },
          SetOptions(merge: true),
        );
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> readCachedDecision(String cacheKey) async {
    try {
      final snapshot = await _firestore
          .collection('outfit_ai_cache')
          .doc(_cacheId(cacheKey))
          .get();
      final data = snapshot.data();
      if (data == null) return null;
      final expiresAt = _timestamp(data['expiresAt']);
      if (expiresAt.isBefore(DateTime.now().toUtc())) return null;
      final decision = data['decision'];
      return decision is Map ? Map<String, dynamic>.from(decision) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCachedDecision(
    String cacheKey,
    Map<String, dynamic> decision, {
    Duration ttl = const Duration(hours: 1),
  }) async {
    await _firestore
        .collection('outfit_ai_cache')
        .doc(_cacheId(cacheKey))
        .set(<String, dynamic>{
      'decision': decision,
      'expiresAt': Timestamp.fromDate(DateTime.now().toUtc().add(ttl)),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _cacheId(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  DateTime _timestamp(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  String _dayKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
