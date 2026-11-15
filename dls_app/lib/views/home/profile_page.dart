import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/wardrobe_controller.dart';
import '../../core/legal/legal_content.dart';
import '../../core/theme/app_theme.dart';
import '../../models/profile_analytics_state.dart';
import '../../services/account_deletion_service.dart';
import '../../services/demo_data_service.dart';
import '../../services/image_compression_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/context_tip_card.dart';
import '../analytics/wardrobe_analytics_page.dart';
import '../legal/legal_page.dart';

class ProfileAnalyticsSummary extends StatelessWidget {
  const ProfileAnalyticsSummary({
    super.key,
    required this.metrics,
    this.onRetry,
  });

  final ProfileAnalyticsState metrics;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _statTile(metrics.itemCount?.toString() ?? 'Loading', 'Items in Closet')),
            const SizedBox(width: 10),
            Expanded(
              child: _statTile(
                metrics.styleScore?.toStringAsFixed(1) ?? 'Unavailable',
                'Style Score',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _statTile(metrics.outfitCount?.toString() ?? 'Loading', 'Outfits Logged')),
            const SizedBox(width: 10),
            Expanded(child: _statTile(metrics.eventCount?.toString() ?? 'Loading', 'Events Planned')),
          ],
        ),
        if (metrics.freshness != AnalyticsFreshness.live && metrics.status != AnalyticsStatus.loading) ...[
          const SizedBox(height: 8),
          Text(
            metrics.freshness == AnalyticsFreshness.cached
                ? 'Showing cached insights. Some values may be stale.'
                : metrics.freshness == AnalyticsFreshness.stale
                    ? 'These insights may be stale. Refresh when connected.'
                    : 'Some insights are unavailable right now.',
            style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
        if (metrics.status != AnalyticsStatus.ready && metrics.status != AnalyticsStatus.loading) ...[
          const SizedBox(height: 6),
          Text(
            metrics.status == AnalyticsStatus.empty
                ? 'No activity yet. Add wardrobe items or generate an outfit to build this view.'
                : metrics.message ?? 'Some metrics are unavailable.',
            style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
          ),
          if (metrics.canRetry)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry insights'),
              ),
            ),
        ],
      ],
    );
  }

  static Widget _statTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  final ImageCompressionService _compression = ImageCompressionService();

  bool _seeding = false;
  bool _resetting = false;
  bool _deletingAccount = false;
  Future<ProfileAnalyticsState>? _metricsFuture;

  Future<bool> _requestImagePermission(ImageSource source) async {
    if (kIsWeb) return true;

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted;
    }

    try {
      final photos = await Permission.photos.request();
      if (photos.isGranted) return true;
    } catch (_) {
      // Fallback for Android API levels where photos permission is unavailable.
    }

    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<Uint8List?> _pickCroppedImage(ImageSource source) async {
    final granted = await _requestImagePermission(source);
    if (!granted) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera/gallery permission is required to change profile photo.')),
      );
      return null;
    }

    final image = await _picker.pickImage(source: source, imageQuality: 90);
    if (image == null) return null;

    final Uint8List bytes;
    if (kIsWeb) {
      bytes = await image.readAsBytes();
    } else {
      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (cropped == null) return null;
      bytes = await cropped.readAsBytes();
    }
    final compressed = await _compression.compressBytes(bytes, maxWidth: 500, jpegQuality: 72);
    return compressed.bytes;
  }

  Future<ProfileAnalyticsState> _loadMetrics(String userId) async {
    return context.read<ProfileService>().loadAnalytics(
          userId,
          fallbackItems: context.read<WardrobeController>().items,
        );
  }

  Future<void> _seedDemoData(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    final demoService = context.read<DemoDataService>();

    final List<DemoPersona> personas;
    try {
      personas = await demoService.loadPersonas();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to load test personas: $e')),
      );
      return;
    }
    if (!mounted) return;

    final personaId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose a test persona'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final persona in personas)
                ListTile(
                  title: Text(persona.displayName),
                  onTap: () => Navigator.of(ctx).pop(persona.id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (personaId == null || !mounted) return;

    setState(() => _seeding = true);
    try {
      final result = await demoService.seedForUser(userId, personaId: personaId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Persona ${result.personaId} seeded: ${result.itemsCreated} items, '
            '${result.outfitsCreated} outfits, ${result.eventsCreated} events '
            '(replaced ${result.replacedDocs} old test docs).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to seed test persona: $e')),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _openEditProfile(String userId, Map<String, dynamic> profile) async {
    final initialName = ((profile['nickname'] as String?) ?? '').trim().isNotEmpty
        ? ((profile['nickname'] as String?) ?? '')
        : ((profile['displayName'] as String?) ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceLow,
      builder: (sheetContext) {
        return _EditProfileSheet(
          userId: userId,
          initialDisplayName: initialName,
          pickCroppedImage: _pickCroppedImage,
        );
      },
    );
  }

  Future<void> _resetCurrentUserData(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    final profileService = context.read<ProfileService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Test Data?'),
        content: const Text(
          'This clears your closet items, outfits, events, and audit logs. Your account, profile, and profile photo will stay intact.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Clear Test Data')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _resetting = true);
    try {
      final result = await profileService.clearCurrentUserTestData(userId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Test data cleared. Items:${result['clothing_items'] ?? 0}, Outfits:${result['outfit_history'] ?? 0}, Events:${result['events'] ?? 0}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to clear test data: $e')),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  void _openLegal(LegalDocumentType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalPage(type: type)),
    );
  }

  Future<void> _confirmDeleteAccount(User user) async {
    final messenger = ScaffoldMessenger.of(context);
    final deletionService = context.read<AccountDeletionService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account, wardrobe photos, outfits, events, insights, and profile photo. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingAccount = true);
    try {
      await deletionService.deleteAccount(user);
      // AppRouter returns to sign-in when the auth state clears.
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(AccountDeletionService.messageFor(e))),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  String _buildInsightMessage(ProfileAnalyticsState metrics) {
    final items = metrics.itemCount;
    final outfits = metrics.outfitCount;
    final topCategory = metrics.topCategory;
    final latestCaption = metrics.latestCaption;

    if (metrics.status == AnalyticsStatus.loading) {
      return 'Loading your style insights.';
    }
    if (metrics.status == AnalyticsStatus.error || metrics.status == AnalyticsStatus.offline) {
      return metrics.message ?? 'Profile insights are unavailable right now. Retry when you are connected.';
    }

    if (items == null || items == 0) {
      return 'Start by uploading a few wardrobe items. Once your closet is populated, your style insights will become much sharper.';
    }

    if (outfits == null || outfits == 0) {
      return 'Your closet is growing. Generate your first outfit to unlock personalized reasoning and history-based style tracking.';
    }

    if (topCategory == null) {
      return 'You already have activity in the app. Keep generating looks and planning events to deepen your style profile.';
    }

    return 'Your strongest wardrobe signal right now is $topCategory. Latest fit vibe: ${latestCaption ?? 'Unavailable'}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final userId = auth.user?.uid ?? '';
    final fallbackName = (auth.user?.email?.split('@').first ?? 'Curator').replaceAll('.', ' ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data?.data() ?? const <String, dynamic>{};
            final nickname = ((profile['nickname'] as String?) ?? '').trim();
            final displayName = ((profile['displayName'] as String?) ?? '').trim();
            final profileImageUrl = ((profile['profileImageUrl'] as String?) ?? '').trim();
            final name = nickname.isNotEmpty ? nickname : (displayName.isNotEmpty ? displayName : fallbackName);

            _metricsFuture ??= _loadMetrics(userId);
            return FutureBuilder<ProfileAnalyticsState>(
              future: _metricsFuture,
              builder: (context, snapshot) {
                final metrics = snapshot.data ?? const ProfileAnalyticsState.loading();

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLow,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 112,
                            height: 112,
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppTheme.primaryContainer, AppTheme.primary, Color(0xFF802918)],
                              ),
                            ),
                            child: profileImageUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(profileImageUrl, fit: BoxFit.cover),
                                  )
                                : const CircleAvatar(
                                    backgroundColor: AppTheme.surfaceHigh,
                                    child: Icon(Icons.person, color: AppTheme.onSurfaceVariant),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 38),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(auth.user?.email ?? '-', style: const TextStyle(color: AppTheme.onSurfaceVariant)),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: userId.isEmpty ? null : () => _openEditProfile(userId, profile),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Profile'),
                          ),
                          const SizedBox(height: 14),
                          ProfileAnalyticsSummary(
                            metrics: metrics,
                            onRetry: () => setState(() => _metricsFuture = null),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLow,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Style Insight', style: TextStyle(color: AppTheme.tertiary, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(
                            _buildInsightMessage(metrics),
                            style: const TextStyle(color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const ContextTipCard(
                      title: 'Profile Shortcuts',
                      message: 'Seed Test Persona fills this account with a 120-item test closet. Clear My Test Data removes it again.',
                      icon: Icons.insights_outlined,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.bar_chart, color: AppTheme.primary),
                        title: const Text('Wardrobe Analytics'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WardrobeAnalyticsPage(),
                          ),
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.auto_awesome, color: AppTheme.primary),
                        title: const Text('Style Evolution Log'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: AppTheme.surfaceLow,
                            builder: (context) {
                              return FutureBuilder<List<StyleEvolutionEntry>>(
                                future: context.read<ProfileService>().loadStyleEvolution(userId),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text('Style evolution is unavailable. Please retry from Profile insights.'),
                                    );
                                  }
                                  final entries = snapshot.data ?? const <StyleEvolutionEntry>[];

                                  if (entries.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('No profile analytics events yet.'),
                                    );
                                  }

                                  return ListView.builder(
                                    itemCount: entries.length,
                                    itemBuilder: (context, index) {
                                      final entry = entries[index];
                                      final createdAt = entry.createdAt;
                                      final formatted = createdAt == null ? '-' : DateFormat.yMMMd().add_jm().format(createdAt);
                                      return ListTile(
                                        leading: const Icon(Icons.timeline, color: AppTheme.primary),
                                        title: Text(entry.label),
                                        subtitle: Text('${entry.description}\n$formatted'),
                                        isThreeLine: true,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (DemoDataService.isDemoEnabled)
                      ElevatedButton.icon(
                        onPressed: _seeding || userId.isEmpty
                            ? null
                            : () => _seedDemoData(userId),
                        icon: _seeding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.data_array),
                        label: Text(
                            _seeding ? 'Seeding Test Persona...' : 'Seed Test Persona'),
                      ),
                    const SizedBox(height: 8),
                    if (DemoDataService.isDemoEnabled)
                      ElevatedButton.icon(
                        onPressed: _resetting || userId.isEmpty
                            ? null
                            : () => _resetCurrentUserData(userId),
                        icon: _resetting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_forever_outlined),
                        label: Text(
                          _resetting ? 'Clearing Test Data...' : 'Clear My Test Data',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C2417),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: auth.signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.privacy_tip_outlined,
                          color: AppTheme.primary,
                        ),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openLegal(LegalDocumentType.privacy),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.gavel_outlined,
                          color: AppTheme.primary,
                        ),
                        title: const Text('Terms of Service'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openLegal(LegalDocumentType.terms),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _deletingAccount || auth.user == null
                          ? null
                          : () => _confirmDeleteAccount(auth.user!),
                      icon: _deletingAccount
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_remove_outlined),
                      label: Text(
                        _deletingAccount ? 'Deleting Account...' : 'Delete Account',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB3261E),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.userId,
    required this.initialDisplayName,
    required this.pickCroppedImage,
  });

  final String userId;
  final String initialDisplayName;
  final Future<Uint8List?> Function(ImageSource source) pickCroppedImage;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _displayNameController;
  Uint8List? _pickedImageBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.initialDisplayName);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _pickFrom(ImageSource source) async {
    final bytes = await widget.pickCroppedImage(source);
    if (bytes == null || !mounted) return;
    setState(() => _pickedImageBytes = bytes);
  }

  Future<void> _save() async {
    final display = _displayNameController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final profileService = context.read<ProfileService>();
    final navigator = Navigator.of(context);

    if (display.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Display name is required.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    String? uploadedImageUrl;
    String? uploadWarning;
    try {
      if (_pickedImageBytes != null) {
        try {
          uploadedImageUrl = await profileService.uploadProfileImage(
            userId: widget.userId,
            imageBytes: _pickedImageBytes!,
          );
        } catch (uploadError) {
          debugPrint('[Profile] Image upload skipped: $uploadError');
          uploadWarning =
              'Photo could not be saved (Storage not enabled yet). Other changes were saved.';
        }
      }

      await profileService.updateProfile(
        userId: widget.userId,
        displayName: display,
        nickname: display,
        profileImageUrl: uploadedImageUrl,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update profile: $e')),
      );
      return;
    }

    // Pop first so the sheet tree is fully unmounted before we touch the messenger.
    if (navigator.canPop()) {
      navigator.pop();
    }

    // Defer snackbar to next frame so the popped route's teardown completes cleanly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(uploadWarning ?? 'Profile updated successfully.'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display Name / Nickname',
                hintText: 'How should we call you?',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Update Profile Picture',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose Camera or Gallery to replace your profile photo.',
              style: TextStyle(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            if (_pickedImageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_pickedImageBytes!, height: 120, fit: BoxFit.cover),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _pickFrom(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _pickFrom(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}


