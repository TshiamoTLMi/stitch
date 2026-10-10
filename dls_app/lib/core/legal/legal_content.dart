/// Shared legal copy and links. Keep web/privacy.html and
/// web/delete-account.html in sync with this file when text changes.
enum LegalDocumentType { privacy, terms }

class LegalConfig {
  const LegalConfig._();

  static const String appName = 'Digital Lesela Sete';

  /// Must be replaced with a monitored mailbox before Play Console submission.
  static const String supportEmail = 'REPLACE_WITH_SUPPORT_EMAIL';

  static const String privacyPolicyUrl =
      'https://digital-les-sete.web.app/privacy.html';
  static const String accountDeletionUrl =
      'https://digital-les-sete.web.app/delete-account.html';
}

class LegalSection {
  const LegalSection(this.heading, this.paragraphs);

  final String heading;
  final List<String> paragraphs;
}

class LegalContent {
  const LegalContent._();

  static String titleFor(LegalDocumentType type) => switch (type) {
    LegalDocumentType.privacy => 'Privacy Policy',
    LegalDocumentType.terms => 'Terms of Service',
  };

  static List<LegalSection> sectionsFor(LegalDocumentType type) =>
      switch (type) {
        LegalDocumentType.privacy => privacySections,
        LegalDocumentType.terms => termsSections,
      };

  static const List<LegalSection> privacySections = [
    LegalSection('What this policy covers', [
      'This policy explains how ${LegalConfig.appName} (the app) handles '
          'personal data in the Android and web versions.',
    ]),
    LegalSection('Information you give us', [
      'Account details: email address, first and last name, nickname, '
          'birthdate, gender, and style preferences. Your password is handled '
          'by Firebase Authentication and is not visible to us.',
      'Profile photo, wardrobe photos, item details (category, colour, '
          'season, style tags), outfits, events, and feedback you give on '
          'outfit suggestions.',
    ]),
    LegalSection('Information from sign-in providers', [
      'If you sign in with Google or Microsoft (or Apple, where offered), we '
          'receive your name and email address from that provider.',
    ]),
    LegalSection('Permissions the app uses', [
      'Camera and photo library: to add wardrobe and profile photos.',
      'Calendar: only if you allow it, the app reads and writes events on '
          'your device calendar for event planning.',
      'Notifications: to remind you about planned events.',
      'The app does not read your device location.',
    ]),
    LegalSection('Weather', [
      'Weather forecasts are requested from Open-Meteo using a default '
          'location. Your device location is not sent.',
    ]),
    LegalSection('How we use information', [
      'To run the app: generate outfit suggestions, show wardrobe insights, '
          'keep your wardrobe in sync, and secure your account.',
      'We do not sell your personal information or use it for advertising.',
    ]),
    LegalSection('Who processes your data', [
      'Google Firebase (Authentication, Cloud Firestore, Cloud Storage) stores '
          'and processes account and app data.',
      'Open-Meteo receives the default location coordinates used for '
          'forecasts.',
    ]),
    LegalSection('Deleting your data', [
      'Profile > Delete Account permanently deletes your account, wardrobe '
          'photos, outfits, events, insight history, and profile photo.',
      'You can also request deletion by emailing ${LegalConfig.supportEmail}.',
    ]),
    LegalSection('Children', [
      'The app is not intended for children under 13. Do not create an '
          'account if you are under 13.',
    ]),
    LegalSection('Security', [
      'Data is sent over encrypted connections. Firebase security rules limit '
          'each account to its own data.',
    ]),
    LegalSection('Changes', [
      'We will update this policy and the in-app copy when our practices '
          'change.',
    ]),
    LegalSection('Contact', [
      'Email: ${LegalConfig.supportEmail}',
    ]),
  ];

  static const List<LegalSection> termsSections = [
    LegalSection('Acceptance', [
      'By creating an account or using the app, you agree to these terms.',
    ]),
    LegalSection('The service', [
      '${LegalConfig.appName} helps you organise your wardrobe and get '
          'outfit suggestions for personal use.',
      'Suggestions are informational and are not professional fashion, '
          'styling, or safety advice.',
    ]),
    LegalSection('Your account', [
      'Keep your sign-in details safe. You must be 13 or older to use the app.',
    ]),
    LegalSection('Your content', [
      'You keep ownership of the photos and details you upload. You allow us '
          'to store and process them to provide the service to you.',
      'Only upload photos you have the right to use.',
    ]),
    LegalSection('Acceptable use', [
      'Do not abuse, reverse engineer, scrape, or attempt to access other '
          'users\' data.',
    ]),
    LegalSection('Ending your use', [
      'You can delete your account at any time from Profile > Delete Account. '
          'We may suspend accounts that break these terms.',
    ]),
    LegalSection('Availability', [
      'The service is provided as is and may change or be interrupted.',
    ]),
    LegalSection('Liability', [
      'To the extent permitted by applicable law, we are not liable for '
          'indirect or consequential losses arising from use of the app.',
    ]),
    LegalSection('Governing law', [
      'To be confirmed before publication.',
    ]),
    LegalSection('Changes', [
      'We will tell you in the app when these terms change.',
    ]),
    LegalSection('Contact', [
      'Email: ${LegalConfig.supportEmail}',
    ]),
  ];
}
