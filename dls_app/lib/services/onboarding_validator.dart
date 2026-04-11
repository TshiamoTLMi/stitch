class OnboardingValidator {
  static int calculateAge(DateTime birthdate, {DateTime? now}) {
    final today = now ?? DateTime.now();
    var age = today.year - birthdate.year;
    if (today.month < birthdate.month ||
        (today.month == birthdate.month && today.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  static String? validate({
    required String fullName,
    required String? gender,
    required DateTime? birthdate,
    required List<String> stylePreferences,
  }) {
    if (fullName.trim().isEmpty) {
      return 'Full name is required.';
    }
    if (gender == null || gender.trim().isEmpty) {
      return 'Gender is required.';
    }
    if (birthdate == null) {
      return 'Birth year is required.';
    }

    final age = calculateAge(birthdate);
    if (age < 13 || age > 100) {
      return 'Age must be between 13 and 100.';
    }

    if (stylePreferences.isEmpty) {
      return 'Select at least one style preference.';
    }

    return null;
  }
}
