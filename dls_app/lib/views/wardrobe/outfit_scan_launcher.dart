import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/vision/outfit_pose_scanner.dart';
import 'scan_review_sheet.dart';

/// Picks full-body outfit photo(s), runs [OutfitPoseScanner], and opens
/// [ScanReviewSheet] for each photo in turn.
///
/// This is the entry point for the Closet FAB's "Scan Full Outfit" actions,
/// and is reusable as-is from onboarding's guided first action (Phase 4) -
/// callers only need a [BuildContext].
class OutfitScanLauncher {
  OutfitScanLauncher._();

  static final ImagePicker _picker = ImagePicker();

  /// Takes one photo with the camera and reviews it.
  static Future<void> captureOne(BuildContext context) async {
    final granted = await _requestCameraPermission();
    if (!context.mounted) return;
    if (!granted) {
      _showMessage(context, 'Camera permission denied.');
      return;
    }
    final photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    if (!context.mounted) return;
    await _scanAndReview(context, photo);
  }

  /// Picks several outfit photos from the gallery and reviews each in turn,
  /// so a user can batch-import multiple outfits in one session.
  static Future<void> pickBatch(BuildContext context) async {
    final granted = await _requestGalleryPermission();
    if (!context.mounted) return;
    if (!granted) {
      _showMessage(context, 'Gallery permission denied.');
      return;
    }
    final photos = await _picker.pickMultiImage();
    if (photos.isEmpty) return;
    for (final photo in photos) {
      if (!context.mounted) return;
      await _scanAndReview(context, photo);
    }
  }

  static Future<void> _scanAndReview(BuildContext context, XFile photo) async {
    final bytes = await photo.readAsBytes();
    final outcome = await OutfitPoseScanner.scan(
      bytes,
      filePath: kIsWeb ? null : photo.path,
    );
    if (!context.mounted) return;
    if (outcome.garments.isEmpty) {
      _showMessage(context, 'Could not find a garment in that photo.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScanReviewSheet(
          garments: outcome.garments,
          approximate: outcome.usedFallbackBands,
        ),
      ),
    );
  }

  static Future<bool> _requestCameraPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> _requestGalleryPermission() async {
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

  static void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
