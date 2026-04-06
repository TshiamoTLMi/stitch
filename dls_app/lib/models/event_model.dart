import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  EventModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.date,
    required this.occasion,
  });

  final String id;
  final String userId;
  final String name;
  final DateTime date;
  final String occasion;

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'date': Timestamp.fromDate(date),
      'occasion': occasion,
    };
  }

  factory EventModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return EventModel(
      id: doc.id,
      userId: (data['user_id'] as String?) ?? '',
      name: (data['name'] as String?) ?? 'Event',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      occasion: (data['occasion'] as String?) ?? 'Event',
    );
  }
}
