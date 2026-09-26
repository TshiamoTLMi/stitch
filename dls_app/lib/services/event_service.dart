import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';
import 'notification_service.dart';

class EventService {
  EventService({NotificationService? notificationService})
      : _notifications = notificationService ?? NotificationService();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final NotificationService _notifications;

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

  Future<EventModel> createEvent(EventModel event) async {
    final doc = await _collection.add(event.toMap());
    final saved = EventModel(
      id: doc.id,
      userId: event.userId,
      name: event.name,
      date: event.date,
      occasion: event.occasion,
      recommendedOutfits: event.recommendedOutfits,
      source: event.source,
      sourceKey: event.sourceKey,
    );
    await _notifications.scheduleEventReminder(saved);
    return saved;
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

  Future<EventModel> updateEvent(EventModel event) async {
    await _collection.doc(event.id).update(event.toMap());
    await _notifications.cancelEventReminder(event);
    await _notifications.scheduleEventReminder(event);
    return event;
  }

  Future<void> deleteEvent(EventModel event) async {
    await _collection.doc(event.id).delete();
    await _notifications.cancelEventReminder(event);
  }

  static List<EventModel> nextLocalDayEvents(
    List<EventModel> events, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final nextDay = DateTime(reference.year, reference.month, reference.day + 1);
    final followingDay = nextDay.add(const Duration(days: 1));
    return events
        .where((event) => !event.date.isBefore(nextDay) && event.date.isBefore(followingDay))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
