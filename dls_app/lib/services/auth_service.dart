import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
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
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      await _auth.signInWithPopup(provider);
      return;
    }

    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final oauthCred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(oauthCred);
    } catch (_) {
      // Fallback path for devices where GoogleSignIn plugin flow fails.
      await _auth.signInWithProvider(GoogleAuthProvider());
    }
  }

  Future<void> signInWithApple() async {
    if (kIsWeb) {
      final provider = OAuthProvider('apple.com');
      await _auth.signInWithPopup(provider);
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      throw FirebaseAuthException(
        code: 'operation-not-supported',
        message: 'Apple sign-in is only available on iOS/macOS for this build.',
      );
    }

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: credential.identityToken,
      accessToken: credential.authorizationCode,
    );

    await _auth.signInWithCredential(oauthCredential);
  }

  Future<void> signInWithMicrosoft() async {
    final provider = OAuthProvider('microsoft.com');
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
      return;
    }

    await _auth.signInWithProvider(provider);
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _google.signOut();
    }
    await _auth.signOut();
  }
}
