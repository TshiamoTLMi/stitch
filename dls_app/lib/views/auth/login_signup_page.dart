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

                  // ── Brand header ──────────────────────────────────────
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

                  // ── Auth controls ─────────────────────────────────────
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

// ── Helpers ───────────────────────────────────────────────────────────────────

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

    final password = _passwordController.text.trim();

    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email and password (min 6 chars).')),
      );
      return;
    }

    if (_isLogin) {
      await controller.signIn(email, password);
    } else {
      await controller.signUp(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final title = _isLogin ? 'Digital\nLesela Sete' : 'Create Your\nStyle DNA';

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1400&q=80',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    AppTheme.background,
                    AppTheme.background,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 14),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: AppTheme.primary.withValues(alpha: 0.16),
                            ),
                            child: const Text(
                              'Digital Atelier',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 52,
                              height: 0.95,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isLogin ? 'Your drip, sorted.' : 'Your digital atelier awaits',
                            style: const TextStyle(color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: AppTheme.surfaceLow.withValues(alpha: 0.82),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Email Address'),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: 'Password'),
                            ),
                            if (auth.errorMessage != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                auth.errorMessage!,
                                style: const TextStyle(color: Color(0xFFFFB4AB)),
                              ),
                            ],
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: auth.isLoading ? null : () => _submit(auth),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(_isLogin ? 'Login' : 'Build My Closet'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: auth.isLoading ? null : auth.signInGoogle,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                                foregroundColor: AppTheme.onSurface,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              ),
                              child: const Text('Continue with Google'),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () => setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin ? 'No account yet? Sign up' : 'Already have an account? Login',
                                style: const TextStyle(color: AppTheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
