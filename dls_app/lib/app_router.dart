import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'services/demo_data_service.dart';
import 'services/profile_service.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/onboarding_screen.dart';
import 'views/auth/signup_screen.dart';
import 'views/home/home_shell.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  String? _profileUid;
  Future<bool>? _profileFuture;

  /// Reuses one check per uid; rebuilds must not start a second persona seed.
  Future<bool> _profileFor(String uid, String? email) {
    if (_profileUid != uid || _profileFuture == null) {
      _profileUid = uid;
      _profileFuture = _resolveProfile(
        context.read<ProfileService>(),
        context.read<DemoDataService>(),
        uid,
        email,
      );
    }
    return _profileFuture!;
  }

  void _clearProfileCache() {
    _profileUid = null;
    _profileFuture = null;
  }

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
          future: _profileFor(user.uid, user.email),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (profileSnapshot.hasError) {
              return _ProfileErrorScreen(
                onRetry: () => setState(_clearProfileCache),
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

/// Persona test accounts are provisioned on first sign-in (debug builds only).
Future<bool> _resolveProfile(
  ProfileService profiles,
  DemoDataService demo,
  String uid,
  String? email,
) async {
  if (await profiles.hasProfile(uid)) return true;
  final personaId = personaIdForEmail(email);
  if (personaId == null || !DemoDataService.isDemoEnabled) return false;
  await demo.seedForUser(uid, personaId: personaId);
  return true;
}

class _ProfileErrorScreen extends StatelessWidget {
  const _ProfileErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load your profile. Check your connection.'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
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
