import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';
import 'notification_service.dart';

class EventService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('events');

  Stream<List<EventModel>> streamUpcomingEvents(String userId) {
    try {
      return _collection.where('user_id', isEqualTo: userId).snapshots().map((snapshot) {
        final now = DateTime.now();
        final events = snapshot.docs.map(EventModel.fromDoc).where((event) {
          final day = DateTime(event.date.year, event.date.month, event.date.day);
          final today = DateTime(now.year, now.month, now.day);
          return day.isAtSameMomentAs(today) || day.isAfter(today);
        }).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        return events;
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  Future<void> createEvent(EventModel event) async {
    try {
      final doc = await _collection.add(event.toMap());
      // Schedule a local reminder 1 hour before the event.
      final saved = EventModel(
        id: doc.id,
        userId: event.userId,
        name: event.name,
        date: event.date,
        occasion: event.occasion,
        recommendedOutfits: event.recommendedOutfits,
      );
      await NotificationService().scheduleEventReminder(saved);
    } catch (_) {
      // Silently degrade — event still created even if notification fails.
    }
  }

  Future<bool> createEventIfMissing(EventModel event) async {
    final sourceKey = event.sourceKey;
    if (sourceKey != null && sourceKey.isNotEmpty) {
      final existing = await _collection
          .where('user_id', isEqualTo: event.userId)
          .where('source_key', isEqualTo: sourceKey)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return false;
      }
    }

    await createEvent(event);
    return true;
  }

  Future<void> deleteEvent(EventModel event) async {
    try {
      await _collection.doc(event.id).delete();
      await NotificationService().cancelEventReminder(event);
    } catch (_) {}
  }
}
