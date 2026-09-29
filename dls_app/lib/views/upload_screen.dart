import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/wardrobe_taxonomy.dart';
import '../models/vision_analysis.dart';
import '../services/firebase_service.dart';
import '../services/vision_engine.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, this.visionEngine});

  final VisionEngine? visionEngine;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseService _firebaseService = FirebaseService();
  late final VisionEngine _visionEngine;
  File? _selectedImage;

  /// Picked image path/URL. On web `image_picker` yields a `blob:` URL, not a
  /// filesystem path, so this is the platform-neutral handle used for
  /// "is something selected" checks and for staleness guards.
  String? _selectedPath;

  /// Raw bytes of the pick, used for the preview and vision analysis on every
  /// platform (Safari has no app-owned file system to read from).
  Uint8List? _previewBytes;

  bool get _hasSelection => _selectedPath != null;

  void _clearSelection() {
    setState(() {
      _selectedImage = null;
      _selectedPath = null;
      _previewBytes = null;
    });
  }
  bool _isUploading = false;
  bool _isAiThinking = false;
  final Set<String> _lockedFields = <String>{};
  String? _selectedParentCategory;
  String? _selectedSubcategory;
  String? _selectedFit;
  final TextEditingController _colorController =
      TextEditingController(text: 'black');
  String _selectedSeason = seasonOptions.first;
  String _selectedStatus = statusOptions.first;
  String _selectedGender = genderOptions.first;
  final List<String> _selectedStyleTags = <String>['casual'];
  String? _lastUploadError;

  List<String> get _subcategoryOptions =>
      categoryTaxonomy[_selectedParentCategory] ?? const <String>[];

  bool get _needsFit =>
      _selectedSubcategory != null && requiresFit(_selectedSubcategory!);

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _visionEngine = widget.visionEngine ?? GeminiVisionEngine();
  }

  Future<void> _pickFromCamera() async {
    final granted = await _requestCameraPermission();
    if (!granted) {
      _showMessage('Camera permission denied.');
      return;
    }

    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) {
      _showMessage('Camera capture unavailable. Try Gallery upload.');
      return;
    }

    _selectImage(image);
  }

  Future<void> _pickFromGallery() async {
    final granted = await _requestGalleryPermission();
    if (!granted) {
      _showMessage('Gallery permission denied.');
      return;
    }

    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    _selectImage(image);
  }

  /// Accepts an [XFile] so the same code path works on Android (a real file)
  /// and on web (a `blob:` URL that can only be read as bytes).
  Future<void> _selectImage(XFile picked) async {
    final path = picked.path;
    setState(() {
      _selectedImage = kIsWeb ? null : File(path);
      _selectedPath = path;
      _selectedParentCategory = null;
      _selectedSubcategory = null;
      _selectedFit = null;
      _colorController.clear();
      _lockedFields.clear();
      _isAiThinking = true;
      _lastUploadError = null;
    });

    Uint8List? bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAiThinking = false;
        _lastUploadError = 'Could not read that image. Try another.';
      });
      return;
    }
    if (!mounted || _selectedPath != path) return;
    setState(() => _previewBytes = bytes);
    unawaited(_runVisionAnalysis(path, bytes));
  }

  Future<void> _runVisionAnalysis(String path, Uint8List bytes) async {
    try {
      final result = await _visionEngine.analyzeClothingItem(bytes);
      if (!mounted || _selectedPath != path) return;

      if (result.isNotClothing) {
        _clearSelection();
        setState(() {
          _isAiThinking = false;
          _selectedParentCategory = null;
          _selectedSubcategory = null;
          _selectedFit = null;
          _colorController.clear();
        });
        _showMessage(
            'That does not look like clothing. Please choose a clothing photo.');
        return;
      }

      _applyVisionAnalysis(result);
    } catch (_) {
      if (mounted && _selectedPath == path) {
        setState(() => _isAiThinking = false);
      }
    }
  }

  void _applyVisionAnalysis(VisionAnalysis result) {
    String? parent = _findParent(result.parentCategory ?? result.subcategory);
    String? subcategory = _findSubcategory(result.subcategory);
    if (subcategory != null) {
      parent = categoryTaxonomy.entries
          .firstWhere((entry) => entry.value.contains(subcategory))
          .key;
    }

    setState(() {
      if (!_lockedFields.contains('category')) {
        _selectedParentCategory = parent;
        _selectedSubcategory = subcategory;
      }
      if (!_lockedFields.contains('color') && result.color != null) {
        _colorController.text = result.color!;
      }
      if (!_lockedFields.contains('fit')) {
        _selectedFit = _findFit(result.fit);
      }
      _isAiThinking = false;
    });
  }

  String? _findSubcategory(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = _normalize(value);
    for (final option in categoryTaxonomy.values.expand((items) => items)) {
      final optionNormalized = _normalize(option);
      if (optionNormalized == normalized ||
          optionNormalized == '${normalized}s' ||
          normalized == '${optionNormalized}s') {
        return option;
      }
    }
    const aliases = <String, String>{
      'shirt': 'T-shirts',
      'tshirt': 'T-shirts',
      'tee': 'T-shirts',
      'blazer': 'Blazers',
      'jumpsuit': 'Jumpsuits',
      'pants': 'Trousers',
      'trouser': 'Trousers',
      'shoes': 'Sneakers',
      'shoe': 'Sneakers',
      'sneaker': 'Sneakers',
      'boot': 'Boots',
      'jacket': 'Puffer jackets',
      'coat': 'Trench coats',
      'hat': 'Hats',
      'bag': 'Bags',
      'purse': 'Bags',
      'jewellery': 'Jewelry',
    };
    return aliases[normalized];
  }

  String? _findParent(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = _normalize(value);
    for (final parent in categoryTaxonomy.keys) {
      if (_normalize(parent) == normalized) return parent;
    }
    const aliases = <String, String>{
      'top': 'Tops',
      'shirt': 'Tops',
      'tshirt': 'Tops',
      'blouse': 'Tops',
      'sweater': 'Tops',
      'knitwear': 'Tops',
      'bottom': 'Bottoms',
      'pants': 'Bottoms',
      'trousers': 'Bottoms',
      'jeans': 'Bottoms',
      'skirt': 'Bottoms',
      'dress': 'Dresses & Jumpsuits',
      'dresses': 'Dresses & Jumpsuits',
      'jumpsuit': 'Dresses & Jumpsuits',
      'fullbody': 'Dresses & Jumpsuits',
      'outerwear': 'Outerwear',
      'jacket': 'Outerwear',
      'coat': 'Outerwear',
      'activewear': 'Activewear & Leisure',
      'sportswear': 'Activewear & Leisure',
      'accessory': 'Accessories',
      'accessories': 'Accessories',
      'bag': 'Accessories',
      'hat': 'Accessories',
      'footwear': 'Footwear',
      'shoe': 'Footwear',
      'shoes': 'Footwear',
      'sneaker': 'Footwear',
      'boot': 'Footwear',
    };
    return aliases[normalized];
  }

  String? _findFit(String? value) {
    if (value == null) return null;
    final normalized = _normalize(value);
    for (final fit in fitOptions) {
      if (_normalize(fit) == normalized) return fit;
    }
    return null;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  Future<bool> _requestCameraPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> _requestGalleryPermission() async {
    if (kIsWeb) return true;
    try {
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isGranted) return true;
    } catch (_) {
      // Some platforms do not support Permission.photos.
    }

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<void> _uploadImage() async {
    if (!_hasSelection) {
      _showMessage('Select an image first.');
      return;
    }
    if (_selectedSubcategory == null || _selectedSubcategory!.isEmpty) {
      _showMessage('Subcategory is required.');
      return;
    }
    if (_selectedParentCategory == null || _selectedParentCategory!.isEmpty) {
      _showMessage('Parent category is required.');
      return;
    }
    if (_needsFit && (_selectedFit == null || _selectedFit!.isEmpty)) {
      _showMessage('Fit is required for this subcategory.');
      return;
    }
    if (_selectedStyleTags.isEmpty) {
      _showMessage('Select at least one style tag.');
      return;
    }
    if (_selectedStatus.isEmpty) {
      _showMessage('Status is required.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _firebaseService.uploadClothingItem(
        _selectedImage,
        preReadBytes: _previewBytes,
        parentCategory: _selectedParentCategory!,
        subcategory: _selectedSubcategory!,
        categoryType: deriveCategoryType(
          parentCategory: _selectedParentCategory!,
          subcategory: _selectedSubcategory!,
        ),
        fit: _needsFit ? _selectedFit : null,
        color: _colorController.text.trim().isEmpty
            ? 'black'
            : _colorController.text.trim(),
        colorGroup: deriveColorGroup(_colorController.text),
        styleTags: _selectedStyleTags,
        season: _selectedSeason,
        status: _selectedStatus,
        gender: _selectedGender,
      );
      _lastUploadError = null;
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Added $_selectedSubcategory to your wardrobe!')),
      );
    } catch (e) {
      final msg = e.toString().contains('object-not-found') ||
              e.toString().contains('Storage has not been set up')
          ? 'Upload failed: Firebase Storage is not enabled yet. Go to Firebase Console → Storage → Get Started, then try again.'
          : 'Upload failed: $e';
      _lastUploadError = msg;
      if (!mounted) return;
      _showMessage(msg);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: selected image or dark
          if (_hasSelection)
            _selectedImage != null
                ? Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.4),
                    colorBlendMode: BlendMode.darken,
                  )
                : (_previewBytes != null
                    ? Image.memory(
                        _previewBytes!,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: 0.4),
                        colorBlendMode: BlendMode.darken,
                      )
                    : const ColoredBox(color: Color(0xFF0E0E0E)))
          else
            const ColoredBox(color: Color(0xFF0E0E0E)),

          // Vignette overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.3,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8)
                ],
              ),
            ),
          ),

          // Full content
          SafeArea(
            child: Column(
              children: [
                // Top controls
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleControl(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                      const Text(
                        'LESÉLA SETE',
                        style: TextStyle(
                          color: Color(0xFFF2CA50),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 3,
                        ),
                      ),
                      _CircleControl(
                        onTap: () {},
                        child: const Icon(Icons.flash_on,
                            color: Color(0xFFF2CA50), size: 20),
                      ),
                    ],
                  ),
                ),

                // Viewfinder
                Expanded(
                  child: Center(
                    child: _ViewfinderBox(hasImage: _hasSelection),
                  ),
                ),

                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          // Instruction text
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                  width: 20,
                                  height: 1,
                                  color: const Color(0xFF4D4635)),
                              const SizedBox(width: 10),
                              Text(
                                _hasSelection
                                    ? 'REVIEW YOUR PIECE'
                                    : 'ALIGN YOUR PIECE WITHIN THE FRAME',
                                style: const TextStyle(
                                  color: Color(0xFFD0C5AF),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                  width: 20,
                                  height: 1,
                                  color: const Color(0xFF4D4635)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_hasSelection) ...[
                            if (_lastUploadError != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF802918)
                                      .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  _lastUploadError!,
                                  style: const TextStyle(
                                    color: Color(0xFFFFDAD3),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1B1B)
                                    .withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.category_outlined,
                                          color: Color(0xFFD0C5AF), size: 18),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Parent Category',
                                        style: TextStyle(
                                          color: Color(0xFFD0C5AF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      _VisionField(
                                        isThinking: _isAiThinking,
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedParentCategory,
                                            hint: const Text('Select'),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            dropdownColor:
                                                const Color(0xFF2A2A2A),
                                            style: const TextStyle(
                                              color: Color(0xFFE5E2E1),
                                              fontWeight: FontWeight.w700,
                                            ),
                                            iconEnabledColor:
                                                const Color(0xFFF2CA50),
                                            items: categoryTaxonomy.keys
                                                .map(
                                                  (c) =>
                                                      DropdownMenuItem<String>(
                                                    value: c,
                                                    child: Text(c),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: _isUploading
                                                ? null
                                                : (value) {
                                                    if (value == null) return;
                                                    setState(() {
                                                      _lockedFields
                                                          .add('category');
                                                      _selectedParentCategory =
                                                          value;
                                                      _selectedSubcategory =
                                                          null;
                                                      _selectedFit = null;
                                                    });
                                                  },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.sell_outlined,
                                          color: Color(0xFFD0C5AF), size: 18),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Subcategory',
                                        style: TextStyle(
                                          color: Color(0xFFD0C5AF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      _VisionField(
                                        isThinking: _isAiThinking,
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedSubcategory,
                                            hint: const Text('Select'),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            dropdownColor:
                                                const Color(0xFF2A2A2A),
                                            style: const TextStyle(
                                              color: Color(0xFFE5E2E1),
                                              fontWeight: FontWeight.w700,
                                            ),
                                            iconEnabledColor:
                                                const Color(0xFFF2CA50),
                                            items: _subcategoryOptions
                                                .map(
                                                  (s) =>
                                                      DropdownMenuItem<String>(
                                                    value: s,
                                                    child: Text(s),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: _isUploading
                                                ? null
                                                : (value) => setState(() {
                                                      _lockedFields
                                                          .add('category');
                                                      _selectedSubcategory =
                                                          value;
                                                      _selectedFit = null;
                                                    }),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_needsFit || _isAiThinking) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.straighten_outlined,
                                            color: Color(0xFFD0C5AF), size: 18),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Fit',
                                          style: TextStyle(
                                            color: Color(0xFFD0C5AF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        _VisionField(
                                          isThinking: _isAiThinking,
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedFit,
                                              hint: const Text('Select fit'),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              dropdownColor:
                                                  const Color(0xFF2A2A2A),
                                              style: const TextStyle(
                                                color: Color(0xFFE5E2E1),
                                                fontWeight: FontWeight.w700,
                                              ),
                                              iconEnabledColor:
                                                  const Color(0xFFF2CA50),
                                              items: fitOptions
                                                  .map(
                                                    (f) => DropdownMenuItem<
                                                        String>(
                                                      value: f,
                                                      child: Text(f),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: _isUploading
                                                  ? null
                                                  : (value) => setState(() {
                                                        _lockedFields
                                                            .add('fit');
                                                        _selectedFit = value;
                                                      }),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  _VisionField(
                                    isThinking: _isAiThinking,
                                    child: TextField(
                                      controller: _colorController,
                                      onChanged: (_) =>
                                          _lockedFields.add('color'),
                                      style: const TextStyle(
                                          color: Color(0xFFE5E2E1)),
                                      decoration: const InputDecoration(
                                        labelText: 'Color',
                                        labelStyle:
                                            TextStyle(color: Color(0xFFD0C5AF)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedSeason,
                                          decoration: const InputDecoration(
                                            labelText: 'Season',
                                          ),
                                          items: seasonOptions
                                              .map((s) => DropdownMenuItem(
                                                  value: s, child: Text(s)))
                                              .toList(),
                                          onChanged: _isUploading
                                              ? null
                                              : (value) => setState(
                                                    () => _selectedSeason =
                                                        value ??
                                                            seasonOptions.first,
                                                  ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedStatus,
                                          decoration: const InputDecoration(
                                            labelText: 'Status',
                                          ),
                                          items: statusOptions
                                              .map((s) => DropdownMenuItem(
                                                  value: s, child: Text(s)))
                                              .toList(),
                                          onChanged: _isUploading
                                              ? null
                                              : (value) => setState(
                                                    () => _selectedStatus =
                                                        value ??
                                                            statusOptions.first,
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedGender,
                                    decoration: const InputDecoration(
                                        labelText: 'Gender'),
                                    items: genderOptions
                                        .map((g) => DropdownMenuItem(
                                            value: g, child: Text(g)))
                                        .toList(),
                                    onChanged: _isUploading
                                        ? null
                                        : (value) => setState(() =>
                                            _selectedGender =
                                                value ?? genderOptions.first),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Style tags',
                                      style: TextStyle(
                                        color: const Color(0xFFD0C5AF)
                                            .withValues(alpha: 0.95),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: styleTagOptions
                                        .map(
                                          (tag) => FilterChip(
                                            label: Text(tag),
                                            selected: _selectedStyleTags
                                                .contains(tag),
                                            onSelected: _isUploading
                                                ? null
                                                : (selected) => setState(() {
                                                      if (selected) {
                                                        _selectedStyleTags
                                                            .add(tag);
                                                      } else {
                                                        _selectedStyleTags
                                                            .remove(tag);
                                                      }
                                                    }),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Control row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Gallery button
                              _CircleControl(
                                onTap: _pickFromGallery,
                                child: const Icon(Icons.photo_library_outlined,
                                    color: Color(0xFFD0C5AF), size: 22),
                              ),

                              // Main action
                              if (!_hasSelection)
                                // Shutter button
                                GestureDetector(
                                  onTap: _pickFromCamera,
                                  child: Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFD4AF37)
                                            .withValues(alpha: 0.8),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFD4AF37)
                                              .withValues(alpha: 0.25),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE5E2E1),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                // Upload button
                                GestureDetector(
                                  onTap: _isUploading ? null : _uploadImage,
                                  child: Container(
                                    height: 60,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 28),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFF2CA50),
                                          Color(0xFFD4AF37)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFD4AF37)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: _isUploading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Color(0xFF3C2F00),
                                              ),
                                            )
                                          : const Text(
                                              'Add to Wardrobe',
                                              style: TextStyle(
                                                color: Color(0xFF3C2F00),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                              // Flip / retake
                              _CircleControl(
                                onTap: _hasSelection
                                    ? () =>
                                        setState(_clearSelection)
                                    : _pickFromCamera,
                                child: Icon(
                                  _hasSelection
                                      ? Icons.refresh_rounded
                                      : Icons.flip_camera_ios_outlined,
                                  color: const Color(0xFFD0C5AF),
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // AI pulse orb (decorative)
          Positioned(
            right: 20,
            bottom: 140,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF96E400).withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF96E400).withValues(alpha: 0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Color(0xFF96E400), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _VisionField extends StatelessWidget {
  const _VisionField({required this.isThinking, required this.child});

  final bool isThinking;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (isThinking)
          const Positioned(
            left: 0,
            right: 0,
            bottom: -2,
            child: SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                backgroundColor: Color(0x334D4635),
                color: Color(0xFFF2CA50),
              ),
            ),
          ),
      ],
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ViewfinderBox extends StatelessWidget {
  const _ViewfinderBox({required this.hasImage});

  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.80;
    return SizedBox(
      width: w,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          children: [
            // Faint full border
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF96E400).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            // Corner accents – top-left
            const Positioned(
              top: -1,
              left: -1,
              child: _Corner(top: true, left: true),
            ),
            // top-right
            const Positioned(
              top: -1,
              right: -1,
              child: _Corner(top: true, left: false),
            ),
            // bottom-left
            const Positioned(
              bottom: -1,
              left: -1,
              child: _Corner(top: false, left: true),
            ),
            // bottom-right
            const Positioned(
              bottom: -1,
              right: -1,
              child: _Corner(top: false, left: false),
            ),

            // Pulse line (roughly 25% from top)
            Align(
              alignment: const Alignment(0, -0.5),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF96E400).withValues(alpha: 0.45),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF96E400).withValues(alpha: 0.55),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
            ),

            // Centre hint when no image
            if (!hasImage)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        color: Color(0xFF4D4635), size: 44),
                    SizedBox(height: 10),
                    Text(
                      'TAP SHUTTER TO CAPTURE',
                      style: TextStyle(
                        color: Color(0xFFD0C5AF),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

            // AI tag chips (decorative)
            if (!hasImage)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _AiTag('TYPE: ...'),
                      SizedBox(height: 8),
                      _AiTag('TEXTURE: ...'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _CornerPainter(top: top, left: left)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF96E400)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final dx = left ? 1.0 : -1.0;
    final dy = top ? 1.0 : -1.0;

    canvas.drawLine(Offset(x, y), Offset(x + dx * size.width, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy * size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AiTag extends StatelessWidget {
  const _AiTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border(
          left: BorderSide(color: const Color(0xFF96E400), width: 2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF96E400),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE5E2E1),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
