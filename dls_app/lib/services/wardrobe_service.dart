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
      return _collection.where('userId', isEqualTo: userId).snapshots().map(
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

    if (lastError is FirebaseException && lastError.code == 'unauthorized') {
      throw Exception('Image upload blocked by Firebase Storage rules.');
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

  Future<ClothingItem?> getItem(String id) async {
    final directSnapshot = await _collection.doc(id).get();
    if (directSnapshot.exists) return ClothingItem.fromDoc(directSnapshot);

    final byFieldId =
        await _collection.where('id', isEqualTo: id).limit(1).get();
    if (byFieldId.docs.isEmpty) return null;
    return ClothingItem.fromDoc(byFieldId.docs.first);
  }

  Future<void> deleteFirestoreRecord(String id) async {
    final docRef = await _resolveItemDocRef(id);
    await docRef.delete();
  }

  Future<void> deleteStorageBackup(ClothingItem item) async {
    final paths = <String>{
      if (item.storagePath != null && item.storagePath!.isNotEmpty)
        item.storagePath!,
      if (item.userId.isNotEmpty) 'users/${item.userId}/items/${item.id}.jpg',
      'clothing_items/${item.id}.jpg',
    };
    Object? lastError;

    for (final path in paths) {
      try {
        await _storage.ref(path).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') lastError = error;
      } catch (error) {
        lastError = error;
      }
    }

    if (item.imageUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(item.imageUrl).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') lastError = error;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw Exception('Storage cleanup failed: $lastError');
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> _resolveItemDocRef(
      String id) async {
    final direct = _collection.doc(id);
    final directSnapshot = await direct.get();
    if (directSnapshot.exists) return direct;

    final byFieldId =
        await _collection.where('id', isEqualTo: id).limit(1).get();
    if (byFieldId.docs.isNotEmpty) return byFieldId.docs.first.reference;

    throw Exception('Item not found for id: $id');
  }
}
