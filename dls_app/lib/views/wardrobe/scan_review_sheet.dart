import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants/wardrobe_taxonomy.dart';
import '../../core/vision/outfit_pose_scanner.dart';
import '../../services/firebase_service.dart';

/// Full-screen review for the 1-3 garments auto-extracted from a full-body
/// outfit photo by [OutfitPoseScanner]. Each card is independently editable
/// and discardable; "Save All to Closet" commits the kept cards through the
/// same [FirebaseService.uploadClothingItem] path the single-item upload
/// screen uses, so wardrobe analytics pick them up with no extra wiring.
///
/// [QA TEST POINT] Scan review
/// - Editing a field on one card never affects the others.
/// - Discarding a card removes it from the saved set without crashing.
/// - "Save All" with zero cards left disables the button instead of no-op
///   saving.
class ScanReviewSheet extends StatefulWidget {
  const ScanReviewSheet({super.key, required this.garments, this.approximate = false});

  final List<ScannedGarment> garments;

  /// True when these crops came from the web fixed-ratio fallback rather
  /// than real on-device pose detection - shown as a one-line disclaimer.
  final bool approximate;

  @override
  State<ScanReviewSheet> createState() => _ScanReviewSheetState();
}

class _ScanReviewSheetState extends State<ScanReviewSheet> {
  final FirebaseService _firebaseService = FirebaseService();
  late final List<_EditableCard> _cards;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cards = widget.garments.map(_EditableCard.fromGarment).toList();
  }

  @override
  void dispose() {
    for (final card in _cards) {
      card.colorController.dispose();
    }
    super.dispose();
  }

  List<_EditableCard> get _keptCards =>
      _cards.where((c) => !c.discarded).toList();

  Future<void> _saveAll() async {
    final kept = _keptCards;
    if (kept.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    final failures = <String>[];
    for (final card in kept) {
      try {
        await _firebaseService.uploadClothingItem(
          card.imageBytes,
          parentCategory: card.parentCategory!,
          subcategory: card.subcategory!,
          categoryType: deriveCategoryType(
            parentCategory: card.parentCategory!,
            subcategory: card.subcategory!,
          ),
          fit: card.needsFit ? card.fit : null,
          color: card.colorController.text.trim().isEmpty
              ? 'black'
              : card.colorController.text.trim(),
          colorGroup: deriveColorGroup(card.colorController.text),
          styleTags: card.styleTags,
          season: card.season,
          status: card.status,
          gender: card.gender,
        );
      } catch (_) {
        failures.add(card.garment.label);
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (failures.isEmpty) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${kept.length} item(s) to your wardrobe!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: ${failures.join(', ')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keptCount = _keptCards.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Review Scan')),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.approximate)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Approximate crop - adjust category and color before saving.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            Expanded(
              child: _cards.isEmpty
                  ? const Center(child: Text('No garments detected in this photo.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) =>
                          _GarmentCard(
                        card: _cards[index],
                        onChanged: () => setState(() {}),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: keptCount == 0 || _isSaving ? null : _saveAll,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(keptCount == 0
                          ? 'Nothing to save'
                          : 'Save All to Closet ($keptCount)'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mutable, per-card editing state built from a [ScannedGarment].
class _EditableCard {
  _EditableCard({
    required this.garment,
    required this.parentCategory,
    required this.subcategory,
    required this.fit,
    required this.colorController,
    required this.season,
    required this.status,
    required this.gender,
    required this.styleTags,
  });

  factory _EditableCard.fromGarment(ScannedGarment garment) {
    return _EditableCard(
      garment: garment,
      parentCategory: garment.parentCategory,
      subcategory: garment.subcategory,
      fit: null,
      colorController: TextEditingController(text: garment.color),
      season: seasonOptions.first,
      status: statusOptions.first,
      gender: genderOptions.first,
      styleTags: <String>['casual'],
    );
  }

  final ScannedGarment garment;
  String? parentCategory;
  String? subcategory;
  String? fit;
  final TextEditingController colorController;
  String season;
  String status;
  String gender;
  List<String> styleTags;
  bool discarded = false;

  Uint8List get imageBytes => garment.imageBytes;

  List<String> get subcategoryOptions =>
      categoryTaxonomy[parentCategory] ?? const <String>[];

  bool get needsFit => subcategory != null && requiresFit(subcategory!);
}

class _GarmentCard extends StatelessWidget {
  const _GarmentCard({required this.card, required this.onChanged});

  final _EditableCard card;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (card.discarded) {
      return Card(
        child: ListTile(
          title: Text('${card.garment.label} discarded'),
          trailing: TextButton(
            onPressed: () {
              card.discarded = false;
              onChanged();
            },
            child: const Text('Undo'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    card.imageBytes,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    card.garment.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Discard ${card.garment.label}',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    card.discarded = true;
                    onChanged();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Full-width, stacked rather than side-by-side: some taxonomy
            // labels ("Dresses & Jumpsuits", "Activewear & Leisure") overflow
            // a half-width slot.
            DropdownButtonFormField<String>(
              initialValue: card.parentCategory,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categoryTaxonomy.keys
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                card.parentCategory = value;
                card.subcategory = card.subcategoryOptions.isNotEmpty
                    ? card.subcategoryOptions.first
                    : null;
                card.fit = null;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: card.subcategoryOptions.contains(card.subcategory)
                  ? card.subcategory
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Subcategory'),
              items: card.subcategoryOptions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (value) {
                card.subcategory = value;
                card.fit = null;
                onChanged();
              },
            ),
            if (card.needsFit) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: card.fit,
                decoration: const InputDecoration(labelText: 'Fit'),
                items: fitOptions
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (value) {
                  card.fit = value;
                  onChanged();
                },
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: card.colorController,
              decoration: const InputDecoration(labelText: 'Color'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: card.season,
                    decoration: const InputDecoration(labelText: 'Season'),
                    items: seasonOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) {
                      card.season = value ?? seasonOptions.first;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: card.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: statusOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) {
                      card.status = value ?? statusOptions.first;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: card.gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: genderOptions
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (value) {
                card.gender = value ?? genderOptions.first;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Style tags', style: Theme.of(context).textTheme.labelMedium),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: styleTagOptions
                  .map(
                    (tag) => FilterChip(
                      label: Text(tag),
                      selected: card.styleTags.contains(tag),
                      onSelected: (selected) {
                        if (selected) {
                          card.styleTags.add(tag);
                        } else {
                          card.styleTags.remove(tag);
                        }
                        onChanged();
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
