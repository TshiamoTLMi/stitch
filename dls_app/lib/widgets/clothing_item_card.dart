import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/clothing_item.dart';

class ClothingItemCard extends StatelessWidget {
  const ClothingItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ClothingItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppTheme.surfaceLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: item.imageUrl.isEmpty
                        ? Container(
                            color: AppTheme.surfaceHighest,
                            child: const Center(child: Icon(Icons.image_not_supported)),
                          )
                        : Image.network(item.imageUrl, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppTheme.surfaceLow.withValues(alpha: 0.8),
                    ),
                    child: Text(
                      item.status == 'clean' ? 'Clean' : 'In the Wash',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.category, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${item.color} - ${item.styleTags.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18)),
                    IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
