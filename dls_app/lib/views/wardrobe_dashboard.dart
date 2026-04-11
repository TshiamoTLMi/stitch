import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class WardrobeDashboard extends StatefulWidget {
  const WardrobeDashboard({super.key});

  @override
  State<WardrobeDashboard> createState() => _WardrobeDashboardState();
}

class _WardrobeDashboardState extends State<WardrobeDashboard> {
  final FirebaseService _svc = FirebaseService();
  int _selectedFilter = 0;
  static const _filters = ['All Items', 'Tops', 'Bottoms', 'Shoes', 'Accessories'];

  bool _matchesFilter(Map<String, dynamic> data) {
    if (_selectedFilter == 0) return true;

    final category = ((data['category'] as String?) ?? '').toLowerCase();
    switch (_selectedFilter) {
      case 1:
        return ['shirt', 'top', 'tshirt', 'tee', 'outerwear', 'jacket']
            .contains(category);
      case 2:
        return ['pants', 'jeans', 'trouser', 'shorts', 'skirt']
            .contains(category);
      case 3:
        return ['shoe', 'shoes', 'sneaker', 'sneakers', 'boot', 'boots']
            .contains(category);
      case 4:
        return ['accessory', 'watch', 'bag', 'hat', 'belt', 'jewelry']
            .contains(category);
      default:
        return true;
    }
  }

  void _openDetail(Map<String, dynamic> data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WardrobeDetailSheet(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Header ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Wardrobe',
                  style: TextStyle(
                    color: Color(0xFFE5E2E1),
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Curating your digital legacy, one piece at a time.',
                  style: TextStyle(color: Color(0xFFD0C5AF), fontSize: 13),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),

        // ── Filter chips ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final sel = i == _selectedFilter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFF2CA50) : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        color: sel ? const Color(0xFF3C2F00) : const Color(0xFFD0C5AF),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 18)),

        // ── Grid / States ─────────────────────────────────────────────────
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _svc.streamClothingItems(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFF2CA50)),
                  ),
                ),
              );
            }

            if (snap.hasError) {
              return SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Firebase not connected.',
                  subtitle: 'Complete setup in README to see your wardrobe.',
                ),
              );
            }

            final docs = snap.data?.docs ?? [];
            final filtered = docs.where((d) => _matchesFilter(d.data())).toList();

            if (docs.isEmpty) {
              return SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.checkroom_outlined,
                  title: 'Your wardrobe is empty.',
                  subtitle: 'Tap + to add your first piece.',
                ),
              );
            }

            if (filtered.isEmpty) {
              return SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.tune,
                  title: 'No items in this filter.',
                  subtitle: 'Try a different category or add more pieces.',
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.70,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final data = filtered[i].data();
                    return GestureDetector(
                      onTap: () => _openDetail(data),
                      child: _WardrobeCard(data: data),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Item card ─────────────────────────────────────────────────────────────────

class _WardrobeCard extends StatelessWidget {
  const _WardrobeCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (data['imageUrl'] as String?) ?? '';
    final category = (data['category'] as String?) ?? 'Item';
    final status = (data['status'] as String?) ?? 'clean';
    final isClean = status.toLowerCase() == 'clean';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image area
          Positioned.fill(
            bottom: 52,
            child: imageUrl.isEmpty
                ? const ColoredBox(
                    color: Color(0xFF0E0E0E),
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFF353534),
                        size: 36,
                      ),
                    ),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, prog) => prog == null
                        ? child
                        : const ColoredBox(
                            color: Color(0xFF0E0E0E),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFF4D4635),
                              ),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFF0E0E0E),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFF353534),
                          size: 36,
                        ),
                      ),
                    ),
                  ),
          ),

          // Status badge
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xBB201f1f),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isClean ? const Color(0xFF96E400) : const Color(0xFFFFB4A5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isClean
                              ? const Color(0xFF96E400).withValues(alpha: 0.7)
                              : const Color(0xFFFFB4A5).withValues(alpha: 0.7),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isClean ? 'Clean' : 'In the Wash',
                    style: const TextStyle(
                      color: Color(0xFFE5E2E1),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Item info footer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 52,
            child: Container(
              color: const Color(0xFF1C1B1B),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _capitalize(category),
                    style: const TextStyle(
                      color: Color(0xFFE5E2E1),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'My Closet',
                    style: TextStyle(
                      color: Color(0xFFD0C5AF),
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Empty / error state ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        children: [
          Icon(icon, size: 72, color: const Color(0xFF353534)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE5E2E1),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFFD0C5AF), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WardrobeDetailSheet extends StatefulWidget {
  const _WardrobeDetailSheet({required this.data});

  final Map<String, dynamic> data;

  @override
  State<_WardrobeDetailSheet> createState() => _WardrobeDetailSheetState();
}

class _WardrobeDetailSheetState extends State<_WardrobeDetailSheet> {
  final FirebaseService _service = FirebaseService();
  static const _categories = ['shirt', 'outerwear', 'pants', 'shoes', 'accessory'];
  static const _statuses = ['clean', 'in the wash'];

  late String _category;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = ((widget.data['category'] as String?) ?? 'shirt').toLowerCase();
    _status = ((widget.data['status'] as String?) ?? 'clean').toLowerCase();
  }

  Future<void> _save() async {
    final id = (widget.data['id'] as String?) ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit item: missing document id.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.updateClothingItem(id, category: _category, status: _status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed. Please retry.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (widget.data['imageUrl'] as String?) ?? '';
    final createdAt = widget.data['createdAt'];

    String createdLabel = 'Unknown date';
    if (createdAt is Timestamp) {
      final d = createdAt.toDate().toLocal();
      createdLabel =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 40),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1B1B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D4635),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(22)),
                  child: imageUrl.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFF0E0E0E),
                          child: Center(
                            child: Icon(Icons.image_not_supported_outlined,
                                color: Color(0xFF353534), size: 44),
                          ),
                        )
                      : Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalizeWord(_category),
                      style: const TextStyle(
                        color: Color(0xFFE5E2E1),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Status', value: _capitalizeWord(_status)),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Added On', value: createdLabel),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Document ID',
                      value: (widget.data['id'] as String?) ?? 'Unknown',
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 92,
                                child: Text(
                                  'Category',
                                  style: TextStyle(
                                    color: Color(0xFFD0C5AF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _category,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: _categories
                                      .map((c) => DropdownMenuItem(value: c, child: Text(_capitalizeWord(c))))
                                      .toList(),
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(() => _category = v ?? _category),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const SizedBox(
                                width: 92,
                                child: Text(
                                  'Status',
                                  style: TextStyle(
                                    color: Color(0xFFD0C5AF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _status,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: _statuses
                                      .map((s) => DropdownMenuItem(value: s, child: Text(_capitalizeWord(s))))
                                      .toList(),
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(() => _status = v ?? _status),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Save Changes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 98,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD0C5AF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE5E2E1),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

String _capitalizeWord(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

