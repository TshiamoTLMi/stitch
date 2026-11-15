import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/real_user_demo_seed_service.dart';
import '../home/home_shell.dart';
import '../wardrobe/outfit_scan_launcher.dart';

/// Shown immediately after onboarding's profile form is saved, so a new user
/// never lands on a confusingly empty Closet tab. Two choices: scan a real
/// outfit photo now, or load a small generic starter wardrobe to explore the
/// app with first.
class GuidedFirstActionScreen extends StatefulWidget {
  const GuidedFirstActionScreen({
    super.key,
    required this.userId,
    this.scanAction,
    this.seedAction,
    this.onComplete,
  });

  final String userId;

  /// Overridable for tests; defaults to [OutfitScanLauncher.captureOne].
  final Future<void> Function(BuildContext context)? scanAction;

  /// Overridable for tests; defaults to [RealUserDemoSeedService.seedForUser].
  final Future<void> Function(String userId)? seedAction;

  /// Overridable for tests; defaults to replacing this screen with
  /// [HomeShell].
  final VoidCallback? onComplete;

  @override
  State<GuidedFirstActionScreen> createState() =>
      _GuidedFirstActionScreenState();
}

class _GuidedFirstActionScreenState extends State<GuidedFirstActionScreen> {
  final _seedService = RealUserDemoSeedService();
  bool _isSeeding = false;

  void _goHome() {
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  Future<void> _scanOutfit() async {
    final action = widget.scanAction ?? OutfitScanLauncher.captureOne;
    await action(context);
    _goHome();
  }

  Future<void> _loadDemoWardrobe() async {
    if (_isSeeding) return;
    setState(() => _isSeeding = true);
    try {
      final action = widget.seedAction ?? _seedService.seedForUser;
      await action(widget.userId);
    } catch (_) {
      // A seed failure must never trap a new user on this screen.
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
    _goHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                "Let's fill your closet",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick one to get started - you can always do the other later.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              _ActionCard(
                icon: Icons.accessibility_new,
                title: 'Scan a Full-Body Photo',
                subtitle: 'Photograph yourself wearing an outfit',
                onTap: _isSeeding ? null : _scanOutfit,
              ),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.checkroom,
                title: 'Load Demo Wardrobe',
                subtitle: 'Start with a few generic items to explore the app',
                loading: _isSeeding,
                onTap: _isSeeding ? null : _loadDemoWardrobe,
              ),
              const Spacer(),
              TextButton(
                onPressed: _isSeeding ? null : _goHome,
                child: const Text("I'll do this later"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
