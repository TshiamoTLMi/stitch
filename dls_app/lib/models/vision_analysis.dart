class VisionAnalysis {
  const VisionAnalysis({
    this.parentCategory,
    this.subcategory,
    this.color,
    this.fit,
    this.error,
  });

  final String? parentCategory;
  final String? subcategory;
  final String? color;
  final String? fit;
  final String? error;

  bool get isNotClothing => error == 'not_clothing';

  factory VisionAnalysis.fromJson(Map<String, dynamic> json) {
    return VisionAnalysis(
      parentCategory:
          _string(json['parentCategory'] ?? json['parent_category']),
      subcategory: _string(json['subcategory'] ?? json['category']),
      color: _string(json['color']),
      fit: _string(json['fit']),
      error: _string(json['error']),
    );
  }

  static String? _string(Object? value) {
    final result = value as String?;
    final trimmed = result?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
