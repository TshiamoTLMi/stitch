import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dls_app/services/account_deletion_service.dart';

void main() {
  group('AccountDeletionService.requiresRecentLogin', () {
    test('detects requires-recent-login', () {
      final error = FirebaseException(
        plugin: 'firebase_auth',
        code: 'requires-recent-login',
      );
      expect(AccountDeletionService.requiresRecentLogin(error), isTrue);
    });

    test('ignores other errors', () {
      final error = FirebaseException(plugin: 'firestore', code: 'unavailable');
      expect(AccountDeletionService.requiresRecentLogin(error), isFalse);
      expect(AccountDeletionService.requiresRecentLogin(StateError('x')),
          isFalse);
    });
  });

  group('AccountDeletionService.messageFor', () {
    test('asks for re-sign-in when recent login is required', () {
      final message = AccountDeletionService.messageFor(
        FirebaseException(plugin: 'firebase_auth', code: 'requires-recent-login'),
      );
      expect(message, contains('sign back in'));
    });

    test('maps permission errors to a support message', () {
      final message = AccountDeletionService.messageFor(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      );
      expect(message, contains('Contact support'));
    });

    test('maps network errors to a safe retry message', () {
      final message = AccountDeletionService.messageFor(
        FirebaseException(plugin: 'firestore', code: 'unavailable'),
      );
      expect(message, contains('retrying is safe'));
    });

    test('falls back to a generic message for unknown errors', () {
      final message = AccountDeletionService.messageFor(StateError('boom'));
      expect(message, startsWith('We could not delete your account'));
    });
  });

  test('owner collections and fields cover all user-scoped data', () {
    expect(AccountDeletionService.userCollections, containsAll(<String>[
      'clothing_items',
      'outfit_history',
      'events',
      'audit_events',
    ]));
    expect(AccountDeletionService.ownerFields, ['userId', 'user_id']);
    expect(AccountDeletionService.pageSize, lessThan(500));
  });
}
