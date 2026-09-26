import 'dart:async';

import 'package:dls_app/controllers/auth_controller.dart';
import 'package:dls_app/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recovery rejects blank and malformed email without calling Firebase', () async {
    var calls = 0;
    final controller = AuthController(
      AuthService(),
      passwordResetAction: (_) async => calls++,
    );

    expect(await controller.sendPasswordReset(''), isFalse);
    expect(controller.recoveryStatus, RecoveryStatus.invalid);
    expect(await controller.sendPasswordReset('not-an-email'), isFalse);
    expect(calls, 0);
  });

  test('recovery prevents duplicate requests and retains normalized email', () async {
    final completer = Completer<void>();
    var calls = 0;
    final controller = AuthController(
      AuthService(),
      passwordResetAction: (_) {
        calls++;
        return completer.future;
      },
    );

    final first = controller.sendPasswordReset('  TEST@example.com ');
    await Future<void>.delayed(Duration.zero);
    final second = await controller.sendPasswordReset('test@example.com');

    expect(controller.recoveryStatus, RecoveryStatus.sending);
    expect(controller.recoveryEmail, 'test@example.com');
    expect(second, isFalse);
    expect(calls, 1);

    completer.complete();
    expect(await first, isTrue);
    expect(controller.recoveryStatus, RecoveryStatus.success);
    expect(controller.recoveryMessage, contains('If an account exists'));
  });
}