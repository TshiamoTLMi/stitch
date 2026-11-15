import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'services/demo_data_service.dart';
import 'services/first_launch_service.dart';
import 'services/profile_service.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/onboarding_screen.dart';
import 'views/auth/signup_screen.dart';
import 'views/home/home_shell.dart';
import 'views/legal/legal_consent_screen.dart';
import 'views/onboarding/value_prop_carousel.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  String? _profileUid;
  Future<bool>? _profileFuture;
  final _firstLaunchService = FirstLaunchService();
  Future<bool>? _carouselSeenFuture;
  bool _carouselDone = false;
  Future<bool>? _legalAcceptedFuture;
  bool _legalAcceptedThisSession = false;
  String? _legalCheckedForUid;

  Future<bool> _carouselSeen() =>
      _carouselSeenFuture ??= _firstLaunchService.hasSeenValuePropCarousel();

  void _markCarouselDone() {
    setState(() => _carouselDone = true);
    _firstLaunchService.markValuePropCarouselSeen();
  }

  /// One check per signed-in uid; a fresh sign-in (different user on the
  /// same device) must re-check rather than reuse another account's answer.
  Future<bool> _legalAcceptedFor(String uid) {
    if (_legalCheckedForUid != uid || _legalAcceptedFuture == null) {
      _legalCheckedForUid = uid;
      _legalAcceptedFuture = _firstLaunchService.hasAcceptedLegalTerms();
    }
    return _legalAcceptedFuture!;
  }

  Future<void> _markLegalAccepted() async {
    await _firstLaunchService.markLegalTermsAccepted();
    if (mounted) setState(() => _legalAcceptedThisSession = true);
  }

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
          if (_carouselDone) return const _AuthSwitcher();
          return FutureBuilder<bool>(
            future: _carouselSeen(),
            builder: (context, carouselSnapshot) {
              if (carouselSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (carouselSnapshot.data ?? false) {
                return const _AuthSwitcher();
              }
              return ValuePropCarousel(onDone: _markCarouselDone);
            },
          );
        }

        return FutureBuilder<bool>(
          future: _legalAcceptedFor(user.uid),
          builder: (context, legalSnapshot) {
            if (legalSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final legalAccepted =
                _legalAcceptedThisSession || (legalSnapshot.data ?? false);
            if (!legalAccepted) {
              return LegalConsentScreen(onAccept: _markLegalAccepted);
            }

            return FutureBuilder<bool>(
              future: _profileFor(user.uid, user.email),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState ==
                    ConnectionState.waiting) {
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
