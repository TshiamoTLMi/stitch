import 'package:cloud_firestore/cloud_firestore.dart';

class ClothingItem {
  ClothingItem({
    required this.id,
    required this.parentCategory,
    required this.subcategory,
    required this.categoryType,
    this.fit,
    required this.color,
    required this.colorGroup,
    required this.styleTags,
    required this.season,
    required this.status,
    required this.gender,
    required this.imageUrl,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String parentCategory;
  final String subcategory;
  final String categoryType;
  final String? fit;
  final String color;
  final String colorGroup;
  final List<String> styleTags;
  final String season;
  final String status;
  final String gender;
  final String imageUrl;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Legacy convenience alias used by older screens.
  String get category => subcategory;

  bool get isClean => status == 'clean';

  Map<String, dynamic> toMap() {
    return {
      'parentCategory': parentCategory,
      'subcategory': subcategory,
      'categoryType': categoryType,
      if (fit != null && fit!.isNotEmpty) 'fit': fit,
      'color': color,
      'colorGroup': colorGroup,
      'styleTags': styleTags,
      'season': season,
      'status': status,
      'gender': gender,
      'image_url': imageUrl,
      'imageUrl': imageUrl,
      'userId': userId,
      'created_at': Timestamp.fromDate(createdAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),

      // Legacy compatibility fields kept during migration.
      'category': subcategory,
      'style_tags': styleTags,
      'user_id': userId,
    };
  }

  factory ClothingItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return ClothingItem(
      id: doc.id,
      parentCategory: (data['parentCategory'] as String?) ?? 'Tops',
      subcategory:
          (data['subcategory'] as String?) ?? (data['category'] as String?) ?? 'T-shirts',
      categoryType: (data['categoryType'] as String?) ?? _legacyCategoryType(data),
      fit: data['fit'] as String?,
      color: (data['color'] as String?) ?? 'black',
      colorGroup: (data['colorGroup'] as String?) ?? 'neutral',
      styleTags: List<String>.from(
        data['styleTags'] as List? ?? data['style_tags'] as List? ?? const <String>[],
      ),
      season: (data['season'] as String?) ?? 'All Season',
      status: (data['status'] as String?) ?? 'clean',
      gender: (data['gender'] as String?) ?? 'Unisex',
      imageUrl: (data['imageUrl'] as String?) ?? (data['image_url'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? (data['user_id'] as String?) ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['created_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ??
          (data['updated_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  static String _legacyCategoryType(Map<String, dynamic> data) {
    final c = ((data['category'] as String?) ?? '').toLowerCase();
    if (c.contains('shoe') || c.contains('boot') || c.contains('sneaker')) {
      return 'shoes';
    }
    if (c.contains('pant') || c.contains('trouser') || c.contains('jean') || c.contains('skirt')) {
      return 'bottom';
    }
    if (c.contains('dress') || c.contains('jumpsuit') || c.contains('romper')) {
      return 'full';
    }
    if (c.contains('bag') || c.contains('belt') || c.contains('hat') || c.contains('scarf') || c.contains('jewel')) {
      return 'accessory';
    }
    return 'top';
  }
}
