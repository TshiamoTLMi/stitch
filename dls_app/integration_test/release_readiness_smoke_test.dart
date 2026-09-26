import 'package:dls_app/controllers/auth_controller.dart';
import 'package:dls_app/services/auth_service.dart';
import 'package:dls_app/views/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('release smoke reaches signed-out recovery checkpoint', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(AuthService()),
        child: MaterialApp(home: LoginScreen(onSwitchToSignup: () {})),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Password'), findsOneWidget);
  });
}