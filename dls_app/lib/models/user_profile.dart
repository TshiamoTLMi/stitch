class UserProfile {
  const UserProfile({
    required this.id,
    this.gender,
    this.genderFilterEnabled = false,
    this.stylePreferences = const <String, dynamic>{},
  });

  final String id;
  final String? gender;
  final bool genderFilterEnabled;
  final Map<String, dynamic> stylePreferences;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'gender': gender,
        'genderFilterEnabled': genderFilterEnabled,
        'stylePreferences': stylePreferences,
      };
}
