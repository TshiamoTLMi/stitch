import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._authService);

  final AuthService _authService;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Stream<User?> get authState => _authService.authState;
  User? get user => _authService.currentUser;

  Future<void> signIn(String email, String password) async {
    await _run(() => _authService.signInWithEmail(email: email, password: password));
  }

  Future<void> signUp(String email, String password) async {
    await _run(() => _authService.signUpWithEmail(email: email, password: password));
  }

  Future<bool> sendPasswordReset(String email) async {
    await _run(() => _authService.sendPasswordResetEmail(email: email));
    return _errorMessage == null;
  }

  Future<void> signOut() async {
    await _run(_authService.signOut);
  }

  Future<void> signInGoogle() async {
    await _run(_authService.signInWithGoogle);
  }

  Future<void> signInApple() async {
    await _run(_authService.signInWithApple);
  }

  Future<void> signInMicrosoft() async {
    await _run(_authService.signInWithMicrosoft);
  }

  Future<void> _run(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' || e.code == 'account-exists-with-different-credential') {
        _errorMessage = 'Google sign-in is blocked by Firebase/Google OAuth configuration. Add the Android SHA-1 and SHA-256 fingerprints for this app in Firebase Console, then download the updated google-services.json.';
      } else {
        _errorMessage = e.message ?? 'Authentication error occurred.';
      }
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed' || e.code == '10') {
        _errorMessage = 'Google sign-in failed on Android. Add the app SHA-1 and SHA-256 fingerprints in Firebase Console, then refresh google-services.json.';
      } else {
        _errorMessage = e.message ?? 'Platform sign-in error occurred.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
