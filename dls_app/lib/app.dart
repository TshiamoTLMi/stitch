import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'views/auth/login_signup_page.dart';

class DlsApp extends StatelessWidget {
  const DlsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Lesela Sete',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginSignupPage(),
    );
  }
}
