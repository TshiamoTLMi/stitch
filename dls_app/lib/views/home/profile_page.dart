import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/wardrobe_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../services/demo_data_service.dart';
import '../../services/image_compression_service.dart';
import '../../services/profile_service.dart';

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

    final bytes = await cropped.readAsBytes();
    final compressed = await _compression.compressBytes(bytes, maxWidth: 500, jpegQuality: 72);
    return compressed.bytes;
  }

  Future<Map<String, dynamic>> _loadMetrics(String userId) async {
    try {
      final clothingLegacy =
          await FirebaseFirestore.instance.collection('clothing_items').where('user_id', isEqualTo: userId).get();
      final clothingNew =
          await FirebaseFirestore.instance.collection('clothing_items').where('userId', isEqualTo: userId).get();
      final historySnapshot =
          await FirebaseFirestore.instance.collection('outfit_history').where('user_id', isEqualTo: userId).get();
      final eventsSnapshot = await FirebaseFirestore.instance.collection('events').where('user_id', isEqualTo: userId).get();

      final clothingDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
        for (final doc in clothingLegacy.docs) doc.id: doc,
        for (final doc in clothingNew.docs) doc.id: doc,
      }.values.toList();

      final scores = historySnapshot.docs
          .map((doc) => (doc.data()['score'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      final avgScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
      final styleScore = (avgScore / 20).clamp(0, 5);

      return {
        'items': clothingDocs.length,
        'outfits': historySnapshot.size,
        'events': eventsSnapshot.size,
        'styleScore': styleScore,
        'topCategory': _deriveTopCategory(clothingDocs),
        'latestCaption': _latestCaption(historySnapshot.docs),
      };
    } catch (_) {
      return {
        'items': 0,
        'outfits': 0,
        'events': 0,
        'styleScore': 0.0,
        'topCategory': 'N/A',
        'latestCaption': 'Generate an outfit to start collecting insights.',
      };
    }
  }

  String _deriveTopCategory(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final counts = <String, int>{};
    for (final doc in docs) {
      final data = doc.data();
      final category = (data['subcategory'] as String?) ?? (data['category'] as String?) ?? 'unknown';
      counts[category] = (counts[category] ?? 0) + 1;
    }

    if (counts.isEmpty) return 'N/A';
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  String _latestCaption(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return 'Generate an outfit to start collecting insights.';

    final sorted = docs.toList()
      ..sort((a, b) {
        final aTs = (a.data()['generated_at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTs = (b.data()['generated_at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTs.compareTo(aTs);
      });

    return (sorted.first.data()['caption'] as String?) ?? 'No caption found for latest outfit.';
  }

  Future<void> _seedDemoData(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _seeding = true);
    try {
      final result = await context.read<DemoDataService>().seedForUser(userId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.itemsRepaired > 0 || result.historyRepaired > 0 || result.eventsRepaired > 0
                ? 'Demo data repaired: ${result.itemsRepaired} items, ${result.historyRepaired} outfits, ${result.eventsRepaired} events.'
                : result.itemsCreated == 0 && result.historyCreated == 0 && result.eventsCreated == 0
                    ? 'Demo data already exists for this user.'
                    : 'Demo data seeded: ${result.itemsCreated} items, ${result.historyCreated} outfits, ${result.eventsCreated} events.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to seed demo data: $e')),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _openEditProfile(String userId, Map<String, dynamic> profile) async {
    final messenger = ScaffoldMessenger.of(context);
    final profileService = context.read<ProfileService>();
    final displayNameController = TextEditingController(
      text: ((profile['nickname'] as String?) ?? '').trim().isNotEmpty
          ? (profile['nickname'] as String?)
          : (profile['displayName'] as String?) ?? '',
    );
    Uint8List? pickedImageBytes;
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceLow,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> pickFrom(ImageSource source) async {
              final bytes = await _pickCroppedImage(source);
              if (bytes == null) return;
              setSheetState(() => pickedImageBytes = bytes);
            }

            Future<void> saveProfile() async {
              final display = displayNameController.text.trim();
              if (display.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Display name is required.')),
                );
                return;
              }

              setSheetState(() => isSaving = true);
              try {
                // Image upload is optional — a Storage failure must not block the profile update.
                String? uploadedImageUrl;
                if (pickedImageBytes != null) {
                  try {
                    uploadedImageUrl = await profileService.uploadProfileImage(
                      userId: userId,
                      imageBytes: pickedImageBytes!,
                    );
                  } catch (uploadError) {
                    debugPrint('[Profile] Image upload skipped: $uploadError');
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Photo could not be saved (Storage not enabled yet). Other changes will be saved.'),
                        ),
                      );
                    }
                  }
                }

                await profileService.updateProfile(
                  userId: userId,
                  displayName: display,
                  nickname: display,
                  profileImageUrl: uploadedImageUrl,
                );

                if (!mounted || !sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully.')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Could not update profile: $e')),
                );
              } finally {
                if (mounted) setSheetState(() => isSaving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: displayNameController,
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
                    if (pickedImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(pickedImageBytes!, height: 120, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSaving ? null : () => pickFrom(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSaving ? null : () => pickFrom(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: isSaving ? null : saveProfile,
                      child: isSaving
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
          },
        );
      },
    );

    displayNameController.dispose();
  }

  Future<void> _resetCurrentUserData(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    final profileService = context.read<ProfileService>();
    final authController = context.read<AuthController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Test Data?'),
        content: const Text(
          'This deletes your profile, closet items, outfits, events, and audit logs for a clean test run.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete Data')),
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
      await authController.signOut();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to clear test data: $e')),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final wardrobe = context.watch<WardrobeController>();
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

            return FutureBuilder<Map<String, dynamic>>(
              future: _loadMetrics(userId),
              builder: (context, snapshot) {
                final metrics = snapshot.data ??
                    {
                      'items': wardrobe.items.length,
                      'outfits': 0,
                      'events': 0,
                      'styleScore': 0.0,
                      'topCategory': 'N/A',
                      'latestCaption': 'Generate an outfit to start collecting insights.',
                    };

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
                          Row(
                            children: [
                              Expanded(child: _statTile('${metrics['items']}', 'Items in Closet')),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _statTile(
                                  (metrics['styleScore'] as double).toStringAsFixed(1),
                                  'Style Score',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _statTile('${metrics['outfits']}', 'Outfits Logged')),
                              const SizedBox(width: 10),
                              Expanded(child: _statTile('${metrics['events']}', 'Events Planned')),
                            ],
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
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Stylist Insight', style: TextStyle(color: AppTheme.tertiary, fontWeight: FontWeight.w700)),
                          SizedBox(height: 8),
                          Text(
                            'Track your outfits and events to unlock stronger personalized style insights.',
                            style: TextStyle(color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.bar_chart, color: AppTheme.primary),
                        title: const Text('Wardrobe Analytics'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
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
                              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('audit_events')
                                    .where('user_id', isEqualTo: userId)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final docs = snapshot.data?.docs ?? [];
                                  final sorted = docs.toList()
                                    ..sort((a, b) {
                                      final aTs = (a.data()['created_at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                                      final bTs = (b.data()['created_at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                                      return bTs.compareTo(aTs);
                                    });

                                  if (sorted.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('No profile analytics events yet.'),
                                    );
                                  }

                                  return ListView.builder(
                                    itemCount: sorted.length,
                                    itemBuilder: (context, index) {
                                      final data = sorted[index].data();
                                      final createdAt = (data['created_at'] as Timestamp?)?.toDate();
                                      final formatted = createdAt == null ? '-' : DateFormat.yMMMd().add_jm().format(createdAt);
                                      return ListTile(
                                        leading: const Icon(Icons.timeline, color: AppTheme.primary),
                                        title: Text((data['type'] as String?) ?? 'event'),
                                        subtitle: Text('${(data['message'] as String?) ?? ''}\n$formatted'),
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
                    ElevatedButton.icon(
                      onPressed: _seeding || userId.isEmpty ? null : () => _seedDemoData(userId),
                      icon: _seeding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.data_array),
                      label: Text(_seeding ? 'Seeding Demo Data...' : 'Seed Demo Data'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _resetting || userId.isEmpty ? null : () => _resetCurrentUserData(userId),
                      icon: _resetting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever_outlined),
                      label: Text(_resetting ? 'Clearing Test Data...' : 'Clear My Test Data'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C2417)),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: auth.signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
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

  Widget _statTile(String value, String label) {
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
