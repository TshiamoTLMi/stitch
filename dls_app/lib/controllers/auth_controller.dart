import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

enum RecoveryStatus { idle, invalid, sending, success, failure, offline, expiredLink }

class AuthController extends ChangeNotifier {
  AuthController(this._authService, {Future<void> Function(String email)? passwordResetAction})
      : _passwordResetAction = passwordResetAction;

  final AuthService _authService;
  final Future<void> Function(String email)? _passwordResetAction;

  bool _isLoading = false;
  String? _errorMessage;
  RecoveryStatus _recoveryStatus = RecoveryStatus.idle;
  String? _recoveryMessage;
  String _recoveryEmail = '';

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  RecoveryStatus get recoveryStatus => _recoveryStatus;
  String? get recoveryMessage => _recoveryMessage;
  String get recoveryEmail => _recoveryEmail;
  bool get isRecoverySending => _recoveryStatus == RecoveryStatus.sending;
  Stream<User?> get authState => _authService.authState;
  User? get user => _authService.currentUser;

  Future<void> signIn(String email, String password) async {
    await _run(() => _authService.signInWithEmail(email: email, password: password));
  }

  Future<void> signUp(String email, String password) async {
    await _run(() => _authService.signUpWithEmail(email: email, password: password));
  }

  Future<bool> sendPasswordReset(String email) async {
    final normalizedEmail = AuthService.normalizeEmail(email);
    _recoveryEmail = normalizedEmail;

    if (!_isValidEmail(normalizedEmail)) {
      _recoveryStatus = RecoveryStatus.invalid;
      _recoveryMessage = 'Enter a valid email address.';
      notifyListeners();
      return false;
    }

    if (isRecoverySending) return false;

    _recoveryStatus = RecoveryStatus.sending;
    _recoveryMessage = null;
    notifyListeners();

    try {
      await (_passwordResetAction?.call(normalizedEmail) ??
          _authService.sendPasswordResetEmail(email: normalizedEmail));
      _recoveryStatus = RecoveryStatus.success;
      _recoveryMessage = 'If an account exists for this email, a reset email has been requested.';
      return true;
    } on FirebaseAuthException catch (error) {
      _recoveryStatus = _statusForRecoveryError(error);
      _recoveryMessage = AuthService.recoveryErrorMessage(error);
      return false;
    } on PlatformException catch (error) {
      _recoveryStatus = RecoveryStatus.failure;
      _recoveryMessage = AuthService.recoveryErrorMessage(error);
      return false;
    } catch (error) {
      _recoveryStatus = RecoveryStatus.failure;
      _recoveryMessage = AuthService.recoveryErrorMessage(error);
      return false;
    } finally {
      if (_recoveryStatus == RecoveryStatus.sending) {
        _recoveryStatus = RecoveryStatus.failure;
        _recoveryMessage = 'We could not complete that request. Please try again.';
      }
      notifyListeners();
    }
  }

  static bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  static RecoveryStatus _statusForRecoveryError(FirebaseAuthException error) {
    if (error.code == 'network-request-failed' || error.code == 'timeout') {
      return RecoveryStatus.offline;
    }
    if (error.code == 'invalid-action-code' || error.code == 'expired-action-code') {
      return RecoveryStatus.expiredLink;
    }
    return RecoveryStatus.failure;
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
        _errorMessage = AuthService.recoveryErrorMessage(e);
      }
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed' || e.code == '10') {
        _errorMessage = 'Google sign-in failed on Android. Add the app SHA-1 and SHA-256 fingerprints in Firebase Console, then refresh google-services.json.';
      } else {
        _errorMessage = AuthService.recoveryErrorMessage(e);
      }
    } catch (e) {
      _errorMessage = AuthService.recoveryErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
