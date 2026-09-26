import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/wardrobe_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clothing_item.dart';
import '../../models/event_model.dart';
import '../../models/missing_item_recommendation.dart';
import '../../services/event_service.dart';
import '../../services/recommendation_service.dart';
import '../upload_screen.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({
    super.key,
    required this.userId,
    this.onOpenGenerator,
    this.wardrobeItems,
    this.upcomingEventsStream,
  });

  final String userId;
  final VoidCallback? onOpenGenerator;
  final List<ClothingItem>? wardrobeItems;
  final Stream<List<EventModel>>? upcomingEventsStream;
  final RecommendationService _recommendationService = RecommendationService();

  @override
  Widget build(BuildContext context) {
    final wardrobe = wardrobeItems ?? context.watch<WardrobeController>().items;
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
          stream: upcomingEventsStream ?? context.read<EventService>().streamUpcomingEvents(userId),
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
            final recommendations = _recommendationService.buildRecommendations(
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
                  if (events.isEmpty)
                    const Text('No upcoming events yet. Add one in Events to get guidance.', style: TextStyle(color: AppTheme.onSurfaceVariant))
                  else
                    ...[
                      ...events.take(3).map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '${event.name} · ${DateFormat.yMMMd().format(event.date)} · ${event.occasion}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      if (recommendations.isEmpty)
                        const Text(
                          'Your wardrobe guidance will appear when event details are available.',
                          style: TextStyle(color: AppTheme.onSurfaceVariant),
                        )
                      else
                        ...recommendations.map(
                          (recommendation) => _RecommendationTile(
                            recommendation: recommendation,
                            onAction: () => _openRecommendation(context, recommendation),
                          ),
                        ),
                    ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _openRecommendation(BuildContext context, MissingItemRecommendation recommendation) {
    if (recommendation.action == RecommendationAction.addToWardrobe) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const UploadScreen()),
      );
      return;
    }
    onOpenGenerator?.call();
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

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.recommendation, required this.onAction});

  final MissingItemRecommendation recommendation;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final isUnknown = recommendation.state == RecommendationState.unknown;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recommendation.need, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(recommendation.reason, style: const TextStyle(color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (isUnknown)
            const Text(
              'Needs more data',
              style: TextStyle(color: Color(0xFFFFB4A5)),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAction,
                icon: Icon(
                  recommendation.action == RecommendationAction.addToWardrobe
                      ? Icons.add
                      : Icons.auto_awesome,
                ),
                label: Text(recommendation.actionLabel),
              ),
            ),
        ],
      ),
    );
  }
}
