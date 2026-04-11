import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  EventModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.date,
    required this.occasion,
    this.recommendedOutfits = const <String>[],
    this.source,
    this.sourceKey,
  });

  final String id;
  final String userId;
  final String name;
  final DateTime date;
  final String occasion;
  final List<String> recommendedOutfits;
  final String? source;
  final String? sourceKey;

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'date': Timestamp.fromDate(date),
      'occasion': occasion,
      'recommended_outfits': recommendedOutfits,
      if (source != null) 'source': source,
      if (sourceKey != null) 'source_key': sourceKey,
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
      recommendedOutfits: List<String>.from(
        data['recommended_outfits'] as List? ?? const <String>[],
      ),
      source: data['source'] as String?,
      sourceKey: data['source_key'] as String?,
    );
  }
}
