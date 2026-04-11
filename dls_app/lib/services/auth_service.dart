import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  GoogleSignIn get _google => GoogleSignIn();

  Stream<User?> get authState {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final credentials = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credentials.user;
    if (user == null) return;
    await _upsertUserProfile(user);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      final user = cred.user;
      if (user != null) {
        await _upsertUserProfile(user);
      }
      return;
    }

    final googleUser = await _google.signIn();
    if (googleUser == null) {
      return;
    }

    final googleAuth = await googleUser.authentication;
    final oauthCred = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(oauthCred);
    final user = cred.user;
    if (user != null) {
      await _upsertUserProfile(user);
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _google.signOut();
    }
    await _auth.signOut();
  }

  Future<void> _upsertUserProfile(User user) {
    return _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'display_name': user.displayName,
      'photo_url': user.photoURL,
      'updated_at': Timestamp.fromDate(DateTime.now()),
      'created_at': FieldValue.serverTimestamp(),
      'exclusion_tags': <String>[],
    }, SetOptions(merge: true));
  }
}
