import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/clothing_item.dart';
import '../models/profile_analytics_state.dart';

class ProfileService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;

  Future<ProfileAnalyticsState> loadAnalytics(
    String userId, {
    List<ClothingItem> fallbackItems = const <ClothingItem>[],
  }) async {
    var hadError = false;
    var clothingRecords = <Map<String, dynamic>>[];
    var outfitRecords = <Map<String, dynamic>>[];
    var eventRecords = <Map<String, dynamic>>[];
    var auditRecords = <Map<String, dynamic>>[];

    try {
      final legacy = await _firestore.collection('clothing_items').where('user_id', isEqualTo: userId).get();
      final current = await _firestore.collection('clothing_items').where('userId', isEqualTo: userId).get();
      clothingRecords = _mergeRecords(legacy.docs, current.docs);
    } catch (_) {
      hadError = true;
      clothingRecords = fallbackItems
          .map((item) => <String, dynamic>{
                'id': item.id,
                'subcategory': item.subcategory,
                'category': item.category,
              })
          .toList();
    }

    try {
      outfitRecords = await _queryRecords('outfit_history', userId);
    } catch (_) {
      hadError = true;
    }
    try {
      eventRecords = await _queryRecords('events', userId);
    } catch (_) {
      hadError = true;
    }
    try {
      auditRecords = await _queryRecords('audit_events', userId);
    } catch (_) {
      hadError = true;
    }

    return analyticsFromRecords(
      clothingRecords: clothingRecords,
      outfitRecords: outfitRecords,
      eventRecords: eventRecords,
      auditRecords: auditRecords,
      hadReadError: hadError,
      usedFallback: hadError && clothingRecords.isNotEmpty,
    );
  }

  Future<List<StyleEvolutionEntry>> loadStyleEvolution(String userId) async {
    final records = await _queryRecords('audit_events', userId);
    return styleEvolutionFromRecords(records);
  }

  static ProfileAnalyticsState analyticsFromRecords({
    required List<Map<String, dynamic>> clothingRecords,
    required List<Map<String, dynamic>> outfitRecords,
    required List<Map<String, dynamic>> eventRecords,
    required List<Map<String, dynamic>> auditRecords,
    bool hadReadError = false,
    bool usedFallback = false,
  }) {
    final uniqueClothing = <String, Map<String, dynamic>>{};
    for (var index = 0; index < clothingRecords.length; index++) {
      final record = clothingRecords[index];
      final id = (record['id'] as String?) ?? 'record-$index';
      uniqueClothing[id] = record;
    }

    final scores = outfitRecords
        .map((record) => (record['score'] as num?)?.toDouble())
        .whereType<double>()
        .where((score) => score.isFinite && score >= 0)
        .toList();
    final styleScore = scores.isEmpty
        ? null
        : (scores.reduce((a, b) => a + b) / scores.length / 20).clamp(0, 5).toDouble();
    final categoryCounts = <String, int>{};
    for (final record in uniqueClothing.values) {
      final category = _readableLabel((record['subcategory'] as String?) ?? (record['category'] as String?));
      if (category != 'Unavailable') categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }
    final topCategory = categoryCounts.isEmpty
        ? null
        : (categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final captions = outfitRecords
        .map((record) => (record['caption'] as String?)?.trim())
        .whereType<String>()
        .where((caption) => caption.isNotEmpty)
        .toList();
    final timeline = styleEvolutionFromRecords(auditRecords);
    final hasData = uniqueClothing.isNotEmpty || outfitRecords.isNotEmpty || eventRecords.isNotEmpty || timeline.isNotEmpty;
    final status = hadReadError
        ? (hasData ? AnalyticsStatus.partial : AnalyticsStatus.error)
        : hasData
            ? AnalyticsStatus.ready
            : AnalyticsStatus.empty;

    return ProfileAnalyticsState(
      status: status,
      freshness: usedFallback
          ? AnalyticsFreshness.cached
          : hadReadError
              ? AnalyticsFreshness.unavailable
              : AnalyticsFreshness.live,
      itemCount: uniqueClothing.length,
      outfitCount: outfitRecords.length,
      eventCount: eventRecords.length,
      styleScore: styleScore,
      topCategory: topCategory,
      latestCaption: captions.isEmpty ? null : captions.first,
      timeline: timeline,
      message: hadReadError
          ? 'Some profile data could not be refreshed. Check your connection and retry.'
          : null,
    );
  }

  static List<StyleEvolutionEntry> styleEvolutionFromRecords(List<Map<String, dynamic>> records) {
    final entries = records.map((record) {
      final type = (record['type'] as String?) ?? '';
      final label = _auditLabel(type);
      final description = ((record['message'] as String?) ?? '').trim();
      return StyleEvolutionEntry(
        createdAt: _dateFrom(record['created_at'] ?? record['createdAt']),
        label: label,
        description: description.isEmpty ? label : description,
      );
    }).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return entries;
  }

  static String _auditLabel(String type) {
    switch (type.toLowerCase()) {
      case 'outfit_generated':
        return 'Outfit generated';
      case 'event_created':
        return 'Event created';
      case 'item_uploaded':
        return 'Wardrobe item added';
      default:
        return 'Activity';
    }
  }

  static String _readableLabel(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'unknown') return 'Unavailable';
    return trimmed
        .split(RegExp(r'[ _-]+'))
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  static DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Future<List<Map<String, dynamic>>> _queryRecords(String collection, String userId) async {
    final legacy = await _firestore.collection(collection).where('user_id', isEqualTo: userId).get();
    final current = await _firestore.collection(collection).where('userId', isEqualTo: userId).get();
    return _mergeRecords(legacy.docs, current.docs);
  }

  static List<Map<String, dynamic>> _mergeRecords(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> first,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> second,
  ) {
    final records = <String, Map<String, dynamic>>{};
    for (final doc in [...first, ...second]) {
      records[doc.id] = <String, dynamic>{'id': doc.id, ...doc.data()};
    }
    return records.values.toList();
  }

  Future<bool> hasProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists;
  }

  Future<String> uploadProfileImage({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    final attempts = [
      'users/$userId/profile.jpg',
      'profile_images/$userId.jpg',
    ];

    FirebaseException? lastError;
    for (final path in attempts) {
      try {
        final ref = _storage.ref().child(path);
        await ref.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        return ref.getDownloadURL();
      } on FirebaseException catch (e) {
        lastError = e;
      }
    }

    if (lastError?.code == 'unauthorized') {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: lastError!.code,
        message: 'Profile upload blocked by Firebase Storage rules for this user/path.',
      );
    }

    throw lastError ?? FirebaseException(plugin: 'firebase_storage', message: 'Profile upload failed.');
  }

  Future<void> saveOnboardingProfile({
    required String userId,
    required String email,
    required String displayName,
    required String firstName,
    required String lastName,
    String nickname = '',
    required String gender,
    required DateTime birthdate,
    required int age,
    required List<String> stylePreferences,
    String profileImageUrl = '',
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nickname,
      'gender': gender,
      'birthdate': Timestamp.fromDate(birthdate),
      'age': age,
      'stylePreferences': stylePreferences,
      'profileImageUrl': profileImageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getProfile(String userId) {
    return _firestore.collection('users').doc(userId).get();
  }

  Future<void> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? displayName,
    String? nickname,
    String? profileImageUrl,
  }) async {
    final payload = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (firstName != null) payload['firstName'] = firstName;
    if (lastName != null) payload['lastName'] = lastName;
    if (displayName != null) payload['displayName'] = displayName;
    if (nickname != null) payload['nickname'] = nickname;
    if (profileImageUrl != null) {
      payload['profileImageUrl'] = profileImageUrl;
    }

    await _firestore.collection('users').doc(userId).set(payload, SetOptions(merge: true));
  }

  Future<Map<String, int>> clearCurrentUserTestData(String userId) async {
    final deleted = <String, int>{};
    deleted['clothing_items'] = await _deleteCollectionDocs('clothing_items', userId);
    deleted['outfit_history'] = await _deleteCollectionDocs('outfit_history', userId);
    deleted['events'] = await _deleteCollectionDocs('events', userId);
    deleted['audit_events'] = await _deleteCollectionDocs('audit_events', userId);

    await _firestore.collection('users').doc(userId).delete();
    deleted['users'] = 1;

    try {
      await _storage.ref().child('users/$userId/profile.jpg').delete();
    } catch (_) {
      // Ignore missing profile image objects.
    }

    return deleted;
  }

  Future<int> _deleteCollectionDocs(String collection, String userId) async {
    final byUserId = await _firestore.collection(collection).where('userId', isEqualTo: userId).get();
    final byLegacyUserId = await _firestore.collection(collection).where('user_id', isEqualTo: userId).get();

    final uniqueDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final doc in byUserId.docs) doc.id: doc,
      for (final doc in byLegacyUserId.docs) doc.id: doc,
    }.values.toList();

    if (uniqueDocs.isEmpty) return 0;

    for (var i = 0; i < uniqueDocs.length; i += 400) {
      final batch = _firestore.batch();
      final end = (i + 400) > uniqueDocs.length ? uniqueDocs.length : (i + 400);
      for (var j = i; j < end; j++) {
        batch.delete(uniqueDocs[j].reference);
      }
      await batch.commit();
    }

    return uniqueDocs.length;
  }
}
