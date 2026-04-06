import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/firebase_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseService _firebaseService = FirebaseService();

  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickFromCamera() async {
    final granted = await _requestCameraPermission();
    if (!granted) {
      _showMessage('Camera permission denied.');
      return;
    }

    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _selectedImage = File(image.path));
  }

  Future<void> _pickFromGallery() async {
    final granted = await _requestGalleryPermission();
    if (!granted) {
      _showMessage('Gallery permission denied.');
      return;
    }

    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _selectedImage = File(image.path));
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> _requestGalleryPermission() async {
    final photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      _showMessage('Select an image first.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _firebaseService.uploadClothingItem(_selectedImage!);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your wardrobe!')),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Upload failed. Configure Firebase first.');
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
          if (_selectedImage != null)
            Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.4),
              colorBlendMode: BlendMode.darken,
            )
          else
            const ColoredBox(color: Color(0xFF0E0E0E)),

          // Vignette overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.3,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
              ),
            ),
          ),

          // Full content
          SafeArea(
            child: Column(
              children: [
                // Top controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleControl(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
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
                        child: const Icon(Icons.flash_on, color: Color(0xFFF2CA50), size: 20),
                      ),
                    ],
                  ),
                ),

                // Viewfinder
                Expanded(
                  child: Center(
                    child: _ViewfinderBox(hasImage: _selectedImage != null),
                  ),
                ),

                // Bottom controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      // Instruction text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 20, height: 1, color: const Color(0xFF4D4635)),
                          const SizedBox(width: 10),
                          Text(
                            _selectedImage != null
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
                          Container(width: 20, height: 1, color: const Color(0xFF4D4635)),
                        ],
                      ),
                      const SizedBox(height: 20),

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
                          if (_selectedImage == null)
                            // Shutter button
                            GestureDetector(
                              onTap: _pickFromCamera,
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
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
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF2CA50), Color(0xFFD4AF37)],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
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
                            onTap: _selectedImage != null
                                ? () => setState(() => _selectedImage = null)
                                : _pickFromCamera,
                            child: Icon(
                              _selectedImage != null
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

