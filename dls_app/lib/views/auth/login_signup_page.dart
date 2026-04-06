import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../home/home_shell.dart';

class LoginSignupPage extends StatelessWidget {
  const LoginSignupPage({super.key});

  void _enter(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero background
          Image.network(
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64'
            '?auto=format&fit=crop&w=1400&q=80',
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.55),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF131313)),
          ),

          // Bottom fade gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  Colors.transparent,
                  AppTheme.background.withValues(alpha: 0.55),
                  AppTheme.background,
                ],
              ),
            ),
          ),

          // Radial gold ambient glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.9,
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 48),

                  // â”€â”€ Brand header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'DIGITAL ATELIER',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Digital\nLesela Sete',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 58,
                          fontWeight: FontWeight.w800,
                          height: 0.92,
                          letterSpacing: -2.5,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Your Drip, Sorted.',
                        style: TextStyle(
                          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontSize: 17,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),

                  // â”€â”€ Auth controls â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Column(
                    children: [
                      // Primary CTA
                      _GoldBorderPill(
                        onTap: () => _enter(context),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.fingerprint, color: AppTheme.primary, size: 26),
                            SizedBox(width: 10),
                            Text(
                              'Enter the Atelier',
                              style: TextStyle(
                                color: AppTheme.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 26),

                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0x33D0C5AF))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'or continue with',
                              style: TextStyle(
                                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0x33D0C5AF))),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Social buttons
                      Row(
                        children: [
                          Expanded(
                            child: _SocialPill(
                              label: 'Google',
                              icon: Icons.g_mobiledata,
                              onTap: () => _enter(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SocialPill(
                              label: 'Apple',
                              icon: Icons.apple,
                              onTap: () => _enter(context),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      Text.rich(
                        TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(
                            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Sign up.',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FooterLink('Privacy'),
                          const SizedBox(width: 28),
                          _FooterLink('Terms'),
                          const SizedBox(width: 28),
                          _FooterLink('Help'),
                        ],
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GoldBorderPill extends StatelessWidget {
  const _GoldBorderPill({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _SocialPill extends StatelessWidget {
  const _SocialPill({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.onSurfaceVariant, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.35),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}
