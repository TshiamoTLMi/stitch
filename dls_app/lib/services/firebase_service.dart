import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

class FirebaseService {
  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  Stream<QuerySnapshot<Map<String, dynamic>>> streamClothingItems({String? userId}) {
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

  Future<void> uploadClothingItem(
    File imageFile, {
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
    final id = _uuid.v4();
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 1080,
      quality: 70,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes == null || compressedBytes.isEmpty) {
      throw Exception('Image compression failed.');
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception('User not signed in.');
    }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final candidatePaths = [
        'users/$userId/items/${ts}_$id.jpg',
        'clothing_items/$id.jpg',
      ];

      String? imageUrl;
      Object? uploadError;
      for (final path in candidatePaths) {
        try {
          final ref = _storage.ref().child(path);
          await ref.putData(
            compressedBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          imageUrl = await ref.getDownloadURL();
          break;
        } catch (e) {
          uploadError = e;
        }
      }

      if (imageUrl == null || imageUrl.isEmpty) {
        if (uploadError is FirebaseException && (uploadError as FirebaseException).code == 'unauthorized') {
          throw Exception('Image upload blocked by Firebase Storage rules.');
        }
        throw Exception('Image upload failed: $uploadError');
      }

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
  }) {
    return _firestore.collection('clothing_items').doc(id).update({
      'category': category.trim().toLowerCase(),
      'status': status.trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
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

      final ref = _storage.ref().child('clothing_items/$id.jpg');
      await ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final newUrl = await ref.getDownloadURL();

    await _firestore.collection('clothing_items').doc(id).update({
      'imageUrl': newUrl,
      'image_url': newUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
