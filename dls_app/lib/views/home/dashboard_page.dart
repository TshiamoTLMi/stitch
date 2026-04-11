import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/wardrobe_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clothing_item.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/recommendation_service.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({super.key, required this.userId});

  final String userId;
  final RecommendationService _recommendationService = RecommendationService();

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>().items;
    final cleanCount = wardrobe.where((item) => item.isClean).length;
    final washCount = wardrobe.length - cleanCount;
    final topCategory = _topCategory(wardrobe);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Home', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Overview of your style engine and upcoming recommendations.',
          style: const TextStyle(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                label: 'Closet Items',
                value: '${wardrobe.length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                label: 'Clean Pieces',
                value: '$cleanCount',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                label: 'In Wash',
                value: '$washCount',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                label: 'Top Category',
                value: topCategory,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<EventModel>>(
          stream: context.read<EventService>().streamUpcomingEvents(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final events = snapshot.data!;
            final missing = _recommendationService.buildMissingItems(
              wardrobe: wardrobe,
              upcomingEvents: events,
            );

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('You might need', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (missing.isEmpty)
                    const Text('You are set for upcoming events.', style: TextStyle(color: AppTheme.onSurfaceVariant))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: missing
                          .map(
                            (m) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(m),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _metricCard({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  String _topCategory(List<ClothingItem> items) {
    if (items.isEmpty) {
      return '-';
    }

    final byCount = <String, int>{};
    for (final item in items) {
      final key = item.category.trim().toLowerCase();
      byCount[key] = (byCount[key] ?? 0) + 1;
    }
    final sorted = byCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}
