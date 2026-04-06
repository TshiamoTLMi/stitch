import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

class FirebaseService {
  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  Stream<QuerySnapshot<Map<String, dynamic>>> streamClothingItems() {
    try {
      return _firestore
          .collection('clothing_items')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<void> uploadClothingItem(File imageFile) async {
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

    final ref = _storage.ref().child('clothing_items/$id.jpg');
    await ref.putData(
      compressedBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final imageUrl = await ref.getDownloadURL();

    await _firestore.collection('clothing_items').doc(id).set({
      'id': id,
      'category': 'shirt',
      'status': 'clean',
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
