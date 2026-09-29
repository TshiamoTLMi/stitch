import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';

/// Local-only hero backdrop for the splash/login screen.
///
/// Deliberately performs NO network image request, so app launch never depends
/// on connectivity (Sprint 9 remediation). Uses only the frozen `SCREENS.md`
/// tokens: background surfaces, gold primary, and a faint monogram watermark.
class _AtelierHeroBackdrop extends StatelessWidget {
  const _AtelierHeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF23201C), Color(0xFF131313), Color(0xFF0E0E0E)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.45),
                radius: 1.15,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.75, -0.15),
                radius: 0.95,
                colors: [
                  AppTheme.primaryContainer.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.62, -0.62),
            child: Text(
              'DLS',
              style: TextStyle(
                fontSize: 132,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
                color: AppTheme.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.72, 0.38),
            child: Icon(
              Icons.auto_awesome_outlined,
              size: 46,
              color: AppTheme.primary.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginSignupPage extends StatefulWidget {
  const LoginSignupPage({super.key});

  @override
  State<LoginSignupPage> createState() => _LoginSignupPageState();
}

class _LoginSignupPageState extends State<LoginSignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showError('Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    if (_isLogin) {
      await auth.signIn(email, password);
    } else {
      await auth.signUp(email, password);
    }
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero background - local only, no network request at launch
          const _AtelierHeroBackdrop(),

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 48),
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
                        Column(
                          children: [
                            _GoldBorderPill(
                              onTap: auth.isLoading ? () {} : () => _submit(auth),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.fingerprint, color: AppTheme.primary, size: 26),
                                  const SizedBox(width: 10),
                                  if (auth.isLoading)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.primary,
                                      ),
                                    )
                                  else
                                    Text(
                                      _isLogin ? 'Login with Email' : 'Create with Email',
                                      style: const TextStyle(
                                        color: AppTheme.onSurface,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLow.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(hintText: 'Email address'),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(hintText: 'Password'),
                                  ),
                                ],
                              ),
                            ),
                            if (auth.errorMessage != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                auth.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 26),
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
                            Row(
                              children: [
                                Expanded(
                                  child: _SocialPill(
                                    label: auth.isLoading ? 'Please wait' : 'Google',
                                    icon: Icons.g_mobiledata,
                                    onTap: auth.isLoading ? () {} : auth.signInGoogle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Text.rich(
                              TextSpan(
                                text: _isLogin ? "Don't have an account? " : 'Already have an account? ',
                                style: TextStyle(
                                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: _isLogin ? 'Sign up.' : 'Login.',
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: auth.isLoading ? null : () => setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin ? 'Switch to Sign Up' : 'Switch to Login',
                                style: const TextStyle(color: AppTheme.primary),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Helpers

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
