import 'package:flutter/material.dart';

import '../../core/legal/legal_content.dart';
import 'legal_page.dart';

/// Shown once, right after the user's first successful sign-up or sign-in on
/// a device, before they reach onboarding or the home shell. Must be accepted
/// to continue; [FirstLaunchService.markLegalTermsAccepted] then suppresses
/// it on every later launch on this device.
class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({super.key, required this.onAccept});

  final Future<void> Function() onAccept;

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  bool _agreed = false;
  bool _submitting = false;

  void _openLegalPage(LegalDocumentType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalPage(type: type)),
    );
  }

  Future<void> _continue() async {
    if (!_agreed || _submitting) return;
    setState(() => _submitting = true);
    await widget.onAccept();
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Before you continue',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                '${LegalConfig.appName} needs you to review how your data is '
                'handled before you create or sign in to an account.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              _LegalLinkTile(
                title: 'Privacy Policy',
                icon: Icons.privacy_tip_outlined,
                onTap: () => _openLegalPage(LegalDocumentType.privacy),
              ),
              const SizedBox(height: 8),
              _LegalLinkTile(
                title: 'Terms of Service',
                icon: Icons.description_outlined,
                onTap: () => _openLegalPage(LegalDocumentType.terms),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _submitting
                    ? null
                    : () => setState(() => _agreed = !_agreed),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: _submitting
                            ? null
                            : (value) =>
                                setState(() => _agreed = value ?? false),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'I have read and agree to the Privacy Policy and '
                            'Terms of Service.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _agreed && !_submitting ? _continue : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept and continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalLinkTile extends StatelessWidget {
  const _LegalLinkTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
