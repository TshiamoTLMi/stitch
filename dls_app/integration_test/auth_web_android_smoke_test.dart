import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:dls_app/controllers/auth_controller.dart';
import 'package:dls_app/services/auth_service.dart';
import 'package:dls_app/views/auth/login_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login screen and forgot-password dialog smoke test', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(AuthService()),
          ),
        ],
        child: MaterialApp(
          home: LoginScreen(
            onSwitchToSignup: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'invalid-email');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });
}
