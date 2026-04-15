import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;

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
      'clothing_items/profile_$userId.jpg',
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
