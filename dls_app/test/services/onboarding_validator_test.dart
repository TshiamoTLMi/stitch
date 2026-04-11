import 'package:dls_app/services/onboarding_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingValidator.calculateAge', () {
    test('calculates age correctly before birthday in current year', () {
      final age = OnboardingValidator.calculateAge(
        DateTime(2000, 12, 10),
        now: DateTime(2026, 4, 11),
      );

      expect(age, 25);
    });

    test('calculates age correctly after birthday in current year', () {
      final age = OnboardingValidator.calculateAge(
        DateTime(2000, 1, 10),
        now: DateTime(2026, 4, 11),
      );

      expect(age, 26);
    });
  });

  group('OnboardingValidator.validate', () {
    test('returns error when required fields are missing', () {
      final error = OnboardingValidator.validate(
        fullName: '',
        gender: null,
        birthdate: null,
        stylePreferences: const [],
      );

      expect(error, isNotNull);
    });

    test('returns error when age is outside 13 to 100', () {
      final tooYoung = OnboardingValidator.validate(
        fullName: 'User Name',
        gender: 'Male',
        birthdate: DateTime.now().subtract(const Duration(days: 365 * 10)),
        stylePreferences: const ['Minimal'],
      );

      expect(tooYoung, 'Age must be between 13 and 100.');
    });

    test('returns null for valid payload', () {
      final error = OnboardingValidator.validate(
        fullName: 'User Name',
        gender: 'Female',
        birthdate: DateTime.now().subtract(const Duration(days: 365 * 24)),
        stylePreferences: const ['Minimal', 'Street Flex'],
      );

      expect(error, isNull);
    });
  });
}
