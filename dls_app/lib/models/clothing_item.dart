import 'package:cloud_firestore/cloud_firestore.dart';

class ClothingItem {
  ClothingItem({
    required this.id,
    required this.category,
    required this.color,
    required this.styleTags,
    required this.status,
    required this.imageUrl,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String category;
  final String color;
  final List<String> styleTags;
  final String status;
  final String imageUrl;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isClean => status == 'clean';

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'color': color,
      'style_tags': styleTags,
      'status': status,
      'image_url': imageUrl,
      'user_id': userId,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  factory ClothingItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return ClothingItem(
      id: doc.id,
      category: (data['category'] as String?) ?? 'shirt',
      color: (data['color'] as String?) ?? 'black',
      styleTags: List<String>.from(data['style_tags'] as List? ?? const <String>[]),
      status: (data['status'] as String?) ?? 'clean',
      imageUrl: (data['image_url'] as String?) ?? '',
      userId: (data['user_id'] as String?) ?? '',
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
