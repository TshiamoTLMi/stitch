import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'services/profile_service.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/onboarding_screen.dart';
import 'views/auth/signup_screen.dart';
import 'views/home/home_shell.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return StreamBuilder(
      stream: auth.authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const _AuthSwitcher();
        }

        return FutureBuilder<bool>(
          future: context.read<ProfileService>().hasProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final hasProfile = profileSnapshot.data ?? false;
            if (!hasProfile) {
              return const OnboardingScreen();
            }

            return const HomeShell();
          },
        );
      },
    );
  }
}

class _AuthSwitcher extends StatefulWidget {
  const _AuthSwitcher();

  @override
  State<_AuthSwitcher> createState() => _AuthSwitcherState();
}

class _AuthSwitcherState extends State<_AuthSwitcher> {
  bool _showSignup = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _showSignup
          ? SignupScreen(
              key: const ValueKey('signup_screen'),
              onSwitchToLogin: () => setState(() => _showSignup = false),
            )
          : LoginScreen(
              key: const ValueKey('login_screen'),
              onSwitchToSignup: () => setState(() => _showSignup = true),
            ),
    );
  }
}
