import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/clothing_item.dart';

class WardrobeService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('clothing_items');

  Stream<List<ClothingItem>> streamItems(String userId) {
    try {
      return _collection
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map(ClothingItem.fromDoc).toList(),
          );
    } catch (_) {
      return Stream.value([]);
    }
  }

  Future<String> uploadImage({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final paths = [
      'users/$userId/items/${ts}_manual.$extension',
      'clothing_items/${ts}_manual.$extension',
    ];

    Object? lastError;
    for (final path in paths) {
      try {
        final ref = _storage.ref(path);
        await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        return ref.getDownloadURL();
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Image upload failed: $lastError');
  }

  Future<void> createItem(ClothingItem item) async {
    await _collection.add(item.toMap());
  }

  Future<void> updateItem({
    required String id,
    String? category,
    String? color,
    List<String>? styleTags,
    String? status,
  }) async {
    await _collection.doc(id).update({
      if (category != null) 'category': category,
      if (color != null) 'color': color,
      if (styleTags != null) 'style_tags': styleTags,
      if (status != null) 'status': status,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteItem(String id) async {
    await _collection.doc(id).delete();
  }
}
