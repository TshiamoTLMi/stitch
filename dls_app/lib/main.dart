import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'controllers/auth_controller.dart';
import 'controllers/wardrobe_controller.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/event_service.dart';
import 'services/wardrobe_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const DlsBootstrap());
}

class DlsBootstrap extends StatelessWidget {
  const DlsBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<WardrobeService>(create: (_) => WardrobeService()),
        Provider<EventService>(create: (_) => EventService()),
        ChangeNotifierProvider<AuthController>(
          create: (context) => AuthController(context.read<AuthService>()),
        ),
        ChangeNotifierProvider<WardrobeController>(
          create: (context) => WardrobeController(context.read<WardrobeService>()),
        ),
      ],
      child: const DlsApp(),
    );
  }
}
