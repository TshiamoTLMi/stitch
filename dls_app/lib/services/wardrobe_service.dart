import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/clothing_item.dart';

class WardrobeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('clothing_items');

  Stream<List<ClothingItem>> streamItems(String userId) {
    return _collection
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(ClothingItem.fromDoc).toList(),
        );
  }

  Future<String> uploadImage({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('users/$userId/wardrobe/item_$ts.$extension');
    await ref.putData(bytes);
    return ref.getDownloadURL();
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
