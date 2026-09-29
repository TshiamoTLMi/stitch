import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/utils/item_image.dart';
import '../services/firebase_service.dart';
import '../services/wardrobe_repository.dart';

class WardrobeDashboard extends StatefulWidget {
  const WardrobeDashboard({super.key, required this.userId});

  final String userId;

  @override
  State<WardrobeDashboard> createState() => _WardrobeDashboardState();
}

class _WardrobeDashboardState extends State<WardrobeDashboard> {
  final FirebaseService _svc = FirebaseService();
  int _selectedFilter = 0;
  final Set<String> _selectedItemIds = <String>{};
  bool _isDeletingSelected = false;
  static const _filters = [
    'All Items',
    'Tops',
    'Bottoms',
    'Shoes',
    'Accessories'
  ];

  bool _matchesFilter(Map<String, dynamic> data) {
    if (_selectedFilter == 0) return true;

    final category = ((data['category'] as String?) ?? '').toLowerCase();
    final subcategory = ((data['subcategory'] as String?) ?? '').toLowerCase();
    final categoryType =
        ((data['categoryType'] as String?) ?? '').toLowerCase();
    final parentCategory =
        ((data['parentCategory'] as String?) ?? '').toLowerCase();
    final values = {category, subcategory, categoryType, parentCategory};
    switch (_selectedFilter) {
      case 1:
        return values.intersection({
          'shirt',
          'top',
          'tshirt',
          'tee',
          'outerwear',
          'jacket',
          'tops',
          'full body',
          'full'
        }).isNotEmpty;
      case 2:
        return values.intersection({
          'pants',
          'jeans',
          'trouser',
          'trousers',
          'shorts',
          'skirt',
          'bottom',
          'bottoms'
        }).isNotEmpty;
      case 3:
        return values.intersection({
          'shoe',
          'shoes',
          'sneaker',
          'sneakers',
          'boot',
          'boots',
          'footwear'
        }).isNotEmpty;
      case 4:
        return values.intersection({
          'accessory',
          'accessories',
          'watch',
          'bag',
          'hat',
          'belt',
          'jewelry'
        }).isNotEmpty;
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

  void _toggleSelection(String id) {
    if (id.isEmpty || _isDeletingSelected) return;
    setState(() {
      if (!_selectedItemIds.add(id)) _selectedItemIds.remove(id);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedItemIds.isEmpty || _isDeletingSelected) return;

    final count = _selectedItemIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $count items?'),
        content: const Text(
            'This removes the photos, wardrobe records, and backups.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingSelected = true);
    try {
      final repository = context.read<WardrobeRepository>();
      for (final id in _selectedItemIds.toList()) {
        await repository.deleteClothingItem(id);
      }
      if (!mounted) return;
      setState(() {
        _selectedItemIds.clear();
        _isDeletingSelected = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count items deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeletingSelected = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
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
                if (_selectedItemIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '${_selectedItemIds.length} selected',
                        style: const TextStyle(
                          color: Color(0xFFF2CA50),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isDeletingSelected
                            ? null
                            : () => setState(_selectedItemIds.clear),
                        child: const Text('Clear'),
                      ),
                      FilledButton.icon(
                        onPressed: _isDeletingSelected ? null : _deleteSelected,
                        icon: _isDeletingSelected
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
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
                  onTap: () => setState(() {
                    _selectedFilter = i;
                    _selectedItemIds.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFFF2CA50)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        color: sel
                            ? const Color(0xFF3C2F00)
                            : const Color(0xFFD0C5AF),
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
          stream: _svc.streamClothingItems(userId: widget.userId),
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

            final docs = (snap.data?.docs ?? []).toList()
              ..sort((a, b) {
                final aData = a.data();
                final bData = b.data();
                final aTs =
                    (aData['createdAt'] ?? aData['created_at']) as Timestamp?;
                final bTs =
                    (bData['createdAt'] ?? bData['created_at']) as Timestamp?;
                final aDate =
                    aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bDate =
                    bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bDate.compareTo(aDate);
              });
            final filtered =
                docs.where((d) => _matchesFilter(d.data())).toList();

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
                    final source = filtered[i];
                    final data = <String, dynamic>{
                      ...source.data(),
                      'id': source.id,
                    };
                    final isSelected = _selectedItemIds.contains(source.id);
                    return GestureDetector(
                      onTap: () => _selectedItemIds.isNotEmpty
                          ? _toggleSelection(source.id)
                          : _openDetail(data),
                      onLongPress: () => _toggleSelection(source.id),
                      child: _WardrobeCard(
                        data: data,
                        isSelected: isSelected,
                      ),
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
  const _WardrobeCard({required this.data, this.isSelected = false});
  final Map<String, dynamic> data;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        (data['imageUrl'] as String?) ?? (data['image_url'] as String?) ?? '';
    final imageProvider = resolveImageSource(
      url: imageUrl,
      localPath: (data['localImagePath'] as String?) ??
          (data['local_image_path'] as String?),
    );
    final category = (data['category'] as String?) ?? 'Item';
    final status = ((data['status'] as String?) ?? 'clean').toLowerCase();
    final isClean = status == 'clean';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(18),
        border: isSelected
            ? Border.all(color: const Color(0xFFF2CA50), width: 2)
            : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image area
          Positioned.fill(
            bottom: 52,
            child: imageProvider == null
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
                : Image(
                    image: ResizeImage(imageProvider, width: 420),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
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
                      color: isClean
                          ? const Color(0xFF96E400)
                          : const Color(0xFFFFB4A5),
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

          if (isSelected)
            const Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: Color(0xFFF2CA50),
                child: Icon(Icons.check, color: Color(0xFF3C2F00), size: 17),
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
  final ImagePicker _picker = ImagePicker();
  static const _categories = [
    'shirt',
    'outerwear',
    'pants',
    'shoes',
    'accessory'
  ];
  static const _statuses = ['clean', 'in_wash', 'in the wash'];

  late String _category;
  late String _status;
  bool _saving = false;
  bool _replacingPhoto = false;
  String? _localImagePath; // preview of newly selected photo before upload

  List<String> get _categoryOptions {
    final options = _categories.toList();
    if (_category.isNotEmpty && !options.contains(_category)) {
      options.add(_category);
    }
    return options;
  }

  List<String> get _statusOptions {
    final options = _statuses.toList();
    if (_status.isNotEmpty && !options.contains(_status)) {
      options.add(_status);
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    _category = ((widget.data['category'] as String?) ?? 'shirt').toLowerCase();
    _status = ((widget.data['status'] as String?) ?? 'clean').toLowerCase();
  }

  Future<void> _pickAndReplacePhoto() async {
    final id = (widget.data['id'] as String?) ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot replace photo: missing document id.')),
      );
      return;
    }

    // Let user choose camera or gallery.
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1C1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFFF2CA50)),
              title: const Text('Take a photo',
                  style: TextStyle(color: Color(0xFFE5E2E1))),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFFF2CA50)),
              title: const Text('Choose from gallery',
                  style: TextStyle(color: Color(0xFFE5E2E1))),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null || !mounted) return;

    setState(() {
      _replacingPhoto = true;
      _localImagePath = picked.path;
    });

    try {
      await _service.replaceItemImage(id, File(picked.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _localImagePath = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _replacingPhoto = false);
    }
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
      await _service.updateClothingItem(id,
          category: _category, status: _status);
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

  Future<void> _delete() async {
    final id = (widget.data['id'] as String?) ?? '';
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete item?'),
        content:
            const Text('This removes the photo, wardrobe record, and backup.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await context.read<WardrobeRepository>().deleteClothingItem(id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (widget.data['imageUrl'] as String?) ??
        (widget.data['image_url'] as String?) ??
        '';
    final createdAt = widget.data['createdAt'] ?? widget.data['created_at'];

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
              // ── Photo with Replace button overlay ───────────────────────
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(22)),
                      child: _localImagePath != null
                          ? Image.file(File(_localImagePath!),
                              fit: BoxFit.cover)
                          : imageUrl.isEmpty
                              ? const ColoredBox(
                                  color: Color(0xFF0E0E0E),
                                  child: Center(
                                    child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Color(0xFF353534),
                                        size: 44),
                                  ),
                                )
                              : Image(
                                  image: resolveImageSource(
                                          url: imageUrl,
                                          localPath: _localImagePath) ??
                                      NetworkImage(imageUrl),
                                  fit: BoxFit.cover),
                    ),
                  ),
                  // Replace photo button — bottom-right corner of image
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _replacingPhoto ? null : _pickAndReplacePhoto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1C1B1B).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFFF2CA50)
                                  .withValues(alpha: 0.5)),
                        ),
                        child: _replacingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFF2CA50),
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_outlined,
                                      color: Color(0xFFF2CA50), size: 15),
                                  SizedBox(width: 6),
                                  Text(
                                    'Replace Photo',
                                    style: TextStyle(
                                      color: Color(0xFFF2CA50),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
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
                    _DetailRow(
                        label: 'Status', value: _capitalizeWord(_status)),
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
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  items: _categoryOptions
                                      .map((c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(_capitalizeWord(c))))
                                      .toList(),
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(
                                          () => _category = v ?? _category),
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
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  items: _statusOptions
                                      .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(_capitalizeWord(s))))
                                      .toList(),
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(
                                          () => _status = v ?? _status),
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
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Save Changes'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _delete,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete Item'),
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
