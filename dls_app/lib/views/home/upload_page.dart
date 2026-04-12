import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/wardrobe_taxonomy.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clothing_item.dart';
import '../../services/wardrobe_service.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key, required this.userId});

  final String userId;

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _colorController = TextEditingController(text: 'black');
  String _category = 'shirt';
  String _status = 'clean';
  final List<String> _selectedTags = <String>['casual'];
  bool _isSaving = false;

  Uint8List? _imageBytes;
  String _extension = 'jpg';

  static const categories = [
    'shirt',
    'trousers',
    'jacket',
    'shoes',
    'accessories',
    'dress',
    'shorts',
    'hat',
    'bag',
  ];

  static const styleTags = [
    'formal',
    'casual',
    'streetwear',
    'smart_casual',
    'sportswear',
  ];

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extParts = picked.name.split('.');

    setState(() {
      _imageBytes = bytes;
      _extension = extParts.length > 1 ? extParts.last : 'jpg';
      // MVP closet scanner placeholder defaults.
      _category = 'shirt';
      _selectedTags
        ..clear()
        ..add('casual');
    });
  }

  Future<void> _saveItem() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an image first.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final wardrobeService = context.read<WardrobeService>();
      final imageUrl = await wardrobeService.uploadImage(
        userId: widget.userId,
        bytes: _imageBytes!,
        extension: _extension,
      );

      final now = DateTime.now();
      final item = ClothingItem(
        id: '',
        parentCategory: 'Tops',
        subcategory: _category,
        categoryType: deriveCategoryType(parentCategory: 'Tops', subcategory: _category),
        fit: null,
        color: _colorController.text.trim().isEmpty ? 'black' : _colorController.text.trim(),
        colorGroup: deriveColorGroup(_colorController.text),
        styleTags: _selectedTags,
        season: 'All Season',
        status: _status,
        gender: 'Unisex',
        imageUrl: imageUrl,
        userId: widget.userId,
        createdAt: now,
        updatedAt: now,
      );

      await wardrobeService.createItem(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clothing item uploaded.')));
      setState(() {
        _imageBytes = null;
        _category = 'shirt';
        _selectedTags
          ..clear()
          ..add('casual');
        _status = 'clean';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Closet Scanner', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Align your piece within the frame. MVP defaults to shirt + casual.',
          style: TextStyle(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 340,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLow,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: _imageBytes == null
                        ? Image.network(
                            'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=1200&q=80',
                            fit: BoxFit.cover,
                          )
                        : Image.memory(_imageBytes!, fit: BoxFit.cover),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.62)],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    height: 240,
                    width: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.8), width: 1.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, color: AppTheme.tertiary, size: 44),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    'Tap to change image',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (value) => setState(() => _category = value ?? 'shirt'),
        ),
        const SizedBox(height: 10),
        TextField(controller: _colorController, decoration: const InputDecoration(labelText: 'Color')),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: styleTags
              .map(
                (tag) => FilterChip(
                  label: Text(tag),
                  selected: _selectedTags.contains(tag),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: const [
            DropdownMenuItem(value: 'clean', child: Text('clean')),
            DropdownMenuItem(value: 'in_wash', child: Text('in_wash')),
          ],
          onChanged: (value) => setState(() => _status = value ?? 'clean'),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveItem,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Item to Closet'),
        ),
      ],
    );
  }
}
