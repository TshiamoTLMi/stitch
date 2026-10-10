import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dls_app/core/legal/legal_content.dart';
import 'package:dls_app/views/legal/legal_page.dart';

void main() {
  testWidgets('privacy page lists account deletion and data categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalPage(type: LegalDocumentType.privacy)),
    );

    expect(find.text('Privacy Policy'), findsWidgets);
    final list = find.byType(ListView);
    await tester.dragUntilVisible(
      find.textContaining('does not read your device location'),
      list,
      const Offset(0, -200),
    );
    expect(find.textContaining('does not read your device location'),
        findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Deleting your data'),
      list,
      const Offset(0, -200),
    );
    expect(find.text('Deleting your data'), findsOneWidget);
  });

  testWidgets('terms page renders without the privacy web address', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalPage(type: LegalDocumentType.terms)),
    );

    expect(find.text('Terms of Service'), findsWidgets);
    expect(find.text('Acceptance'), findsOneWidget);
    expect(find.textContaining('Web version:'), findsNothing);
  });
}
