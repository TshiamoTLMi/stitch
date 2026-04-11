import 'package:flutter/material.dart';

import 'app_router.dart';
import 'core/theme/app_theme.dart';

class DlsApp extends StatelessWidget {
  const DlsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Lesela Sete',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppRouter(),
    );
  }
}
