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
    final ref = _storage.ref().child('users/$userId/profile.jpg');
    await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<void> saveOnboardingProfile({
    required String userId,
    required String email,
    required String displayName,
    required String gender,
    required DateTime birthdate,
    required int age,
    required List<String> stylePreferences,
    required String profileImageUrl,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'email': email,
      'displayName': displayName,
      'gender': gender,
      'birthdate': Timestamp.fromDate(birthdate),
      'age': age,
      'stylePreferences': stylePreferences,
      'profileImageUrl': profileImageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
