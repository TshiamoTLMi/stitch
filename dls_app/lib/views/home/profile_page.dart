import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/wardrobe_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../services/demo_data_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _seeding = false;

  Future<Map<String, dynamic>> _loadMetrics(String userId) async {
    try {
      final clothingSnapshot =
          await FirebaseFirestore.instance.collection('clothing_items').where('user_id', isEqualTo: userId).get();
      final historySnapshot =
          await FirebaseFirestore.instance.collection('outfit_history').where('user_id', isEqualTo: userId).get();
      final eventsSnapshot = await FirebaseFirestore.instance.collection('events').where('user_id', isEqualTo: userId).get();

      final scores = historySnapshot.docs
          .map((doc) => (doc.data()['score'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      final avgScore =
          scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
      final styleScore = (avgScore / 20).clamp(0, 5);

      final topCategory = _deriveTopCategory(clothingSnapshot.docs);
      final latestCaption = _latestCaption(historySnapshot.docs);

      return {
        'items': clothingSnapshot.size,
        'outfits': historySnapshot.size,
        'events': eventsSnapshot.size,
        'styleScore': styleScore,
        'topCategory': topCategory,
        'latestCaption': latestCaption,
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
      final category = (doc.data()['category'] as String?) ?? 'unknown';
      counts[category] = (counts[category] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return 'N/A';
    }

    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  String _latestCaption(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return 'Generate an outfit to start collecting insights.';
    }

    final sorted = docs.toList()
      ..sort((a, b) {
        final aTs = (a.data()['generated_at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTs = (b.data()['generated_at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTs.compareTo(aTs);
      });

    return (sorted.first.data()['caption'] as String?) ?? 'No caption found for latest outfit.';
  }

  Future<void> _seedDemoData(String userId) async {
    setState(() => _seeding = true);
    try {
      final result = await context.read<DemoDataService>().seedForUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.itemsCreated == 0 && result.historyCreated == 0 && result.eventsCreated == 0
                ? 'Demo data already exists for this user.'
                : 'Demo data seeded: ${result.itemsCreated} items, ${result.historyCreated} outfits, ${result.eventsCreated} events.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to seed demo data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _seeding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final wardrobe = context.watch<WardrobeController>();
    final userId = auth.user?.uid ?? '';
    final name = (auth.user?.email?.split('@').first ?? 'Curator').replaceAll('.', ' ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FutureBuilder<Map<String, dynamic>>(
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
                child: const CircleAvatar(
                  backgroundImage: NetworkImage(
                    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=700&q=80',
                  ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Stylist Insight', style: TextStyle(color: AppTheme.tertiary, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text(
                'Your strongest lane is ${metrics['topCategory']}. Latest vibe: "${metrics['latestCaption']}"',
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
                            subtitle: Text(
                              '${(data['message'] as String?) ?? ''}\n$formatted',
                            ),
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
          onPressed: auth.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
        ),
              ],
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
