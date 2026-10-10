import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Permanently deletes the signed-in user's cloud data and Auth account.
///
/// Data is removed before the Auth account so that a failure part-way leaves
/// the account in place and the user can safely retry. Auth deletion is last
/// because it cannot be undone.
class AccountDeletionService {
  /// Collections keyed by the owner's uid (`userId` or legacy `user_id`).
  static const List<String> userCollections = [
    'clothing_items',
    'outfit_history',
    'events',
    'audit_events',
  ];

  static const List<String> ownerFields = ['userId', 'user_id'];

  /// Firestore batch limit is 500 operations; stay well under it.
  static const int pageSize = 300;

  Future<void> deleteAccount(User user) async {
    final uid = user.uid;
    if (uid.isEmpty) {
      throw StateError('No signed-in user to delete.');
    }

    final firestore = FirebaseFirestore.instance;
    for (final collection in userCollections) {
      for (final field in ownerFields) {
        await _deleteWhere(firestore, collection, field, uid);
      }
    }
    await firestore.collection('users').doc(uid).delete();

    await _deleteStorageFolder('users/$uid');
    await _deleteStorageFile('profile_images/$uid.jpg');
    await _deleteLocalWardrobeImages();

    await user.delete();
  }

  Future<void> _deleteWhere(
    FirebaseFirestore firestore,
    String collection,
    String field,
    String uid,
  ) async {
    while (true) {
      final snapshot = await firestore
          .collection(collection)
          .where(field, isEqualTo: uid)
          .limit(pageSize)
          .get();
      if (snapshot.docs.isEmpty) return;

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteStorageFolder(String path) async {
    final listing = await FirebaseStorage.instance.ref(path).listAll();
    for (final item in listing.items) {
      await item.delete();
    }
    for (final prefix in listing.prefixes) {
      await _deleteStorageFolder(prefix.fullPath);
    }
  }

  Future<void> _deleteStorageFile(String path) async {
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  Future<void> _deleteLocalWardrobeImages() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/wardrobe_items');
      if (await folder.exists()) {
        await folder.delete(recursive: true);
      }
    } catch (_) {
      // Best effort: local cache is also removed when the app is uninstalled.
    }
  }

  /// True when Firebase needs a fresh sign-in before deleting the account.
  static bool requiresRecentLogin(Object error) =>
      error is FirebaseException && error.code == 'requires-recent-login';

  /// User-facing message for a failed deletion attempt.
  static String messageFor(Object error) {
    if (requiresRecentLogin(error)) {
      return 'For your security, sign out, sign back in, then delete your '
          'account again.';
    }
    final code = error is FirebaseException ? error.code : '';
    if (code == 'permission-denied' || code == 'unauthorized') {
      return 'The server blocked this deletion. Contact support so we can '
          'remove your data.';
    }
    if (code == 'unavailable' || code == 'network-request-failed') {
      return 'Check your connection and try again. Some data may already be '
          'removed; retrying is safe.';
    }
    return 'We could not delete your account. Some data may already be '
        'removed; try again or contact support.';
  }
}
