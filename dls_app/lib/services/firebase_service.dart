import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FirebaseService {
  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  Stream<QuerySnapshot<Map<String, dynamic>>> streamClothingItems(
      {String? userId}) {
    try {
      final uid = userId ?? _auth.currentUser?.uid;
      final base = _firestore.collection('clothing_items');
      if (uid == null || uid.isEmpty) {
        return base.limit(200).snapshots();
      }
      return base.where('userId', isEqualTo: uid).limit(200).snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Uploads a picked photo.
  ///
  /// Pass [preReadBytes] on web, where `image_picker` hands back a `blob:` URL
  /// that has no [File] on disk. Compression goes through `compressWithList`
  /// because `compressWithFile` has no web implementation.
  Future<void> uploadClothingItem(
    File? imageFile, {
    Uint8List? preReadBytes,
    required String parentCategory,
    required String subcategory,
    required String categoryType,
    String? fit,
    required String color,
    required String colorGroup,
    required List<String> styleTags,
    required String season,
    String status = 'clean',
    String gender = 'Unisex',
  }) async {
    final rawBytes = preReadBytes ??
        (imageFile != null ? await imageFile.readAsBytes() : null);
    if (rawBytes == null || rawBytes.isEmpty) {
      throw Exception('No image data to upload.');
    }

    final id = _uuid.v4();
    final compressedBytes = await FlutterImageCompress.compressWithList(
      rawBytes,
      minWidth: 1080,
      quality: 70,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes.isEmpty) {
      throw Exception('Image compression failed.');
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception('User not signed in.');
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final candidatePaths = ['users/$userId/items/${ts}_$id.jpg'];

    String? imageUrl;
    String? storagePath;
    Object? uploadError;
    for (final path in candidatePaths) {
      try {
        final ref = _storage.ref().child(path);
        await ref.putData(
          compressedBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrl = await ref.getDownloadURL();
        storagePath = path;
        break;
      } catch (e) {
        uploadError = e;
      }
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      if (uploadError is FirebaseException &&
          uploadError.code == 'unauthorized') {
        throw Exception('Image upload blocked by Firebase Storage rules.');
      }
      throw Exception('Image upload failed: $uploadError');
    }

    // Web has no app-owned documents directory; the Storage URL is the source.
    final localImagePath = kIsWeb ? null : await _saveLocalImage(id, compressedBytes);

    await _firestore.collection('clothing_items').doc(id).set({
      'id': id,
      'parentCategory': parentCategory,
      'subcategory': subcategory,
      'categoryType': categoryType,
      if (fit != null && fit.trim().isNotEmpty) 'fit': fit,
      'color': color.trim().toLowerCase(),
      'colorGroup': colorGroup,
      'styleTags': styleTags,
      'season': season,
      'status': status.trim().toLowerCase(),
      'gender': gender,
      'userId': userId,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'storagePath': storagePath,
      'createdAt': FieldValue.serverTimestamp(),

      // Legacy compatibility fields during migration.
      'user_id': userId,
      'category': subcategory.trim().toLowerCase(),
      'image_url': imageUrl,
      'created_at': FieldValue.serverTimestamp(),
      'style_tags': styleTags,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateClothingItem(
    String id, {
    required String category,
    required String status,
  }) async {
    final docRef = await _resolveItemDocRef(id);
    final userId = _auth.currentUser?.uid;
    await docRef.update({
      'category': category.trim().toLowerCase(),
      'status': status.trim().toLowerCase(),
      if (userId != null) 'userId': userId,
      if (userId != null) 'user_id': userId,
      'updatedAt': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Compresses [imageFile], uploads it to Storage, then updates the Firestore
  /// doc so the item shows the new photo immediately.
  Future<void> replaceItemImage(String id, File imageFile) async {
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 1080,
      quality: 70,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes == null || compressedBytes.isEmpty) {
      throw Exception('Image compression failed.');
    }

    final docRef = await _resolveItemDocRef(id);
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception('User not signed in.');
    }

    final newUrl = await _uploadItemImageBytes(
      id: docRef.id,
      userId: userId,
      compressedBytes: compressedBytes,
    );

    await docRef.update({
      'imageUrl': newUrl,
      'image_url': newUrl,
      'userId': userId,
      'user_id': userId,
      'updatedAt': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _uploadItemImageBytes({
    required String id,
    required String userId,
    required List<int> compressedBytes,
  }) async {
    final candidatePaths = ['users/$userId/items/$id.jpg'];

    Object? uploadError;
    for (final path in candidatePaths) {
      try {
        final ref = _storage.ref().child(path);
        await ref.putData(
          Uint8List.fromList(compressedBytes),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        return ref.getDownloadURL();
      } catch (e) {
        uploadError = e;
      }
    }

    throw Exception('Image upload failed: $uploadError');
  }

  Future<String> _saveLocalImage(String id, List<int> bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final wardrobeDirectory = Directory('${directory.path}/wardrobe_items');
    await wardrobeDirectory.create(recursive: true);
    final file = File('${wardrobeDirectory.path}/$id.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<DocumentReference<Map<String, dynamic>>> _resolveItemDocRef(
      String id) async {
    final direct = _firestore.collection('clothing_items').doc(id);
    final directSnap = await direct.get();
    if (directSnap.exists) {
      return direct;
    }

    final byFieldId = await _firestore
        .collection('clothing_items')
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    if (byFieldId.docs.isNotEmpty) {
      return byFieldId.docs.first.reference;
    }

    throw Exception('Item not found for id: $id');
  }
}
