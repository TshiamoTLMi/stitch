import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/wardrobe_taxonomy.dart';

class ClothingItem {
  ClothingItem({
    required this.id,
    required this.parentCategory,
    required this.subcategory,
    required this.categoryType,
    this.fit,
    required this.color,
    required String colorGroup,
    required this.styleTags,
    required this.season,
    required this.status,
    required this.gender,
    required this.imageUrl,
    this.localImagePath,
    this.storagePath,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  }) : colorGroup = _resolveColorGroup(colorGroup, color);

  /// Colour groups written by pre-Sprint-9 data. They are re-derived from the
  /// colour so the harmony engine never sees a stale group.
  static const Set<String> legacyColorGroups = <String>{'dark', 'light', 'bright'};

  /// Returns a current colour group, re-deriving it from [color] when the stored
  /// value is missing or a legacy `dark`/`light`/`bright` value.
  static String _resolveColorGroup(String? stored, String color) {
    final value = (stored ?? '').trim().toLowerCase();
    if (value.isNotEmpty && !legacyColorGroups.contains(value)) return value;
    return deriveColorGroup(color);
  }


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
  final String? localImagePath;
  final String? storagePath;
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
      if (localImagePath != null && localImagePath!.isNotEmpty)
        'localImagePath': localImagePath,
      if (storagePath != null && storagePath!.isNotEmpty)
        'storagePath': storagePath,
    };
  }

  factory ClothingItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ClothingItem.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory ClothingItem.fromMap(String id, Map<String, dynamic> data) {
    return ClothingItem(
      id: id,
      parentCategory: (data['parentCategory'] as String?) ?? 'Tops',
      subcategory: (data['subcategory'] as String?) ??
          (data['category'] as String?) ??
          'T-shirts',
      categoryType:
          (data['categoryType'] as String?) ?? _legacyCategoryType(data),
      fit: data['fit'] as String?,
      color: (data['color'] as String?) ?? 'black',
      colorGroup: (data['colorGroup'] as String?) ?? 'neutral',
      styleTags: List<String>.from(
        data['styleTags'] as List? ??
            data['style_tags'] as List? ??
            const <String>[],
      ),
      season: (data['season'] as String?) ?? 'All Season',
      status: (data['status'] as String?) ?? 'clean',
      gender: (data['gender'] as String?) ?? 'Unisex',
      imageUrl:
          (data['imageUrl'] as String?) ?? (data['image_url'] as String?) ?? '',
      localImagePath: (data['localImagePath'] as String?) ??
          (data['local_image_path'] as String?),
      storagePath:
          (data['storagePath'] as String?) ?? (data['storage_path'] as String?),
      userId: (data['userId'] as String?) ?? (data['user_id'] as String?) ?? '',
      createdAt: _readDate(data['createdAt']) ??
          _readDate(data['created_at']) ??
          DateTime.now(),
      updatedAt: _readDate(data['updatedAt']) ??
          _readDate(data['updated_at']) ??
          DateTime.now(),
    );
  }

  /// Returns a copy with the supplied fields replaced. Used when development
  /// seed rows are re-owned by the signed-in user.
  ClothingItem copyWith({
    String? userId,
    String? imageUrl,
    String? localImagePath,
  }) {
    return ClothingItem(
      id: id,
      parentCategory: parentCategory,
      subcategory: subcategory,
      categoryType: categoryType,
      fit: fit,
      color: color,
      colorGroup: colorGroup,
      styleTags: styleTags,
      season: season,
      status: status,
      gender: gender,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      storagePath: storagePath,
      userId: userId ?? this.userId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _legacyCategoryType(Map<String, dynamic> data) {
    final c = ((data['category'] as String?) ?? '').toLowerCase();
    if (c.contains('shoe') || c.contains('boot') || c.contains('sneaker')) {
      return 'shoes';
    }
    if (c.contains('pant') ||
        c.contains('trouser') ||
        c.contains('jean') ||
        c.contains('skirt')) {
      return 'bottom';
    }
    if (c.contains('dress') || c.contains('jumpsuit') || c.contains('romper')) {
      return 'full';
    }
    if (c.contains('bag') ||
        c.contains('belt') ||
        c.contains('hat') ||
        c.contains('scarf') ||
        c.contains('jewel')) {
      return 'accessory';
    }
    return 'top';
  }
}
