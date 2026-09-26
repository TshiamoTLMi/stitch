import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  GoogleSignIn get _google => GoogleSignIn();
  bool _webPersistenceReady = false;

  Future<void> _ensureWebPersistence() async {
    if (!kIsWeb || _webPersistenceReady) return;
    await _auth.setPersistence(Persistence.LOCAL);
    _webPersistenceReady = true;
  }

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  String _normalizeEmail(String email) => normalizeEmail(email);

  static String recoveryErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
        case 'timeout':
          return 'We could not reach the reset service. Check your connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a moment, then try again.';
        case 'invalid-action-code':
        case 'expired-action-code':
          return 'That reset link has expired. Request a new reset email.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        default:
          return 'We could not complete that request. Check your details and try again.';
      }
    }

    return 'We could not complete that request. Check your connection and try again.';
  }

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
    await _ensureWebPersistence();
    await _auth.createUserWithEmailAndPassword(
      email: _normalizeEmail(email),
      password: password,
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _ensureWebPersistence();
    await _auth.signInWithEmailAndPassword(
      email: _normalizeEmail(email),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _ensureWebPersistence();
    await _auth.sendPasswordResetEmail(email: _normalizeEmail(email));
  }

  Future<void> signInWithGoogle() async {
    await _ensureWebPersistence();
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
