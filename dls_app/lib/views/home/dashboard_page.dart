import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/wardrobe_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clothing_item.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/recommendation_service.dart';
import '../../widgets/clothing_item_card.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({super.key, required this.userId});

  final String userId;
  final RecommendationService _recommendationService = RecommendationService();
  static const _filters = ['All Items', 'Tops', 'Bottoms', 'Shoes', 'Accessories'];

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>().items;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('My Wardrobe', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Curating your digital legacy, one piece at a time.',
          style: const TextStyle(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, i) {
              final selected = i == 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _filters[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? const Color(0xFF3C2F00) : AppTheme.onSurface,
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: _filters.length,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          itemCount: wardrobe.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.64,
          ),
          itemBuilder: (context, index) {
            final item = wardrobe[index];
            return ClothingItemCard(
              item: item,
              onEdit: () => _showEditDialog(context, item),
              onDelete: () => _deleteItem(context, item.id),
            );
          },
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

  Future<void> _deleteItem(BuildContext context, String id) async {
    await context.read<WardrobeController>().deleteItem(id);
  }

  Future<void> _showEditDialog(BuildContext context, ClothingItem item) async {
    final categoryController = TextEditingController(text: item.category);
    final colorController = TextEditingController(text: item.color);
    final stylesController = TextEditingController(text: item.styleTags.join(', '));
    String status = item.status;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Clothing Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 8),
              TextField(controller: colorController, decoration: const InputDecoration(labelText: 'Color')),
              const SizedBox(height: 8),
              TextField(
                controller: stylesController,
                decoration: const InputDecoration(labelText: 'Style tags (comma separated)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: status,
                items: const [
                  DropdownMenuItem(value: 'clean', child: Text('clean')),
                  DropdownMenuItem(value: 'in_wash', child: Text('in_wash')),
                ],
                onChanged: (value) {
                  status = value ?? 'clean';
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final styles = stylesController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                await context.read<WardrobeController>().updateItem(
                      id: item.id,
                      category: categoryController.text.trim(),
                      color: colorController.text.trim(),
                      styleTags: styles,
                      status: status,
                    );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
