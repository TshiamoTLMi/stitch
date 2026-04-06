import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  Future<void> signOut() async {
    await _run(_authService.signOut);
  }

  Future<void> signInGoogle() async {
    await _run(_authService.signInWithGoogle);
  }

  Future<void> _run(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Authentication error occurred.';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
