import 'dart:async';

import 'package:dls_app/controllers/auth_controller.dart';
import 'package:dls_app/services/auth_service.dart';
import 'package:dls_app/views/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('recovery shows progress, prevents duplicate taps, and confirms success', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    final auth = AuthController(
      AuthService(),
      passwordResetAction: (_) {
        calls++;
        return completer.future;
      },
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(home: LoginScreen(onSwitchToSignup: () {})),
      ),
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'test@example.com');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump();

    expect(auth.isRecoverySending, isTrue);
    expect(calls, 1);

    completer.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('If an account exists'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}