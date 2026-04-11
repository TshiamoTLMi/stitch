import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';

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

  Future<void> createEvent(EventModel event) {
    try {
      return _collection.add(event.toMap());
    } catch (_) {
      return Future.value();
    }
  }
}
