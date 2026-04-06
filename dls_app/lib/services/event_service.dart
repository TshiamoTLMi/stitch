import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';

class EventService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('events');

  Stream<List<EventModel>> streamUpcomingEvents(String userId) {
    try {
      return _collection
          .where('user_id', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .orderBy('date')
          .snapshots()
          .map((snapshot) => snapshot.docs.map(EventModel.fromDoc).toList());
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
