import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dls_app/views/upload_screen.dart';

/// Guards the accessibility fixes made during the Phase 5 UI/UX audit: a few
/// icon-only controls on [UploadScreen] had no accessible name for
/// screen-reader users. Only controls reachable without driving real
/// camera/gallery platform channels are covered here.
void main() {
  testWidgets('close, gallery and shutter controls all expose a non-empty '
      'semantic label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: UploadScreen()));
    await tester.pump();

    void expectLabelled(IconData icon, String expected) {
      final semantics = tester.getSemantics(find.byIcon(icon));
      expect(semantics.label, expected);
    }

    expectLabelled(Icons.close, 'Close');
    expectLabelled(Icons.photo_library_outlined, 'Choose from gallery');
    // Before an image is picked, the third control takes a photo; find.byIcon
    // would be ambiguous (Icons.close is reused for other UI), so this one
    // is located via its semantics label directly instead.
    expect(find.bySemanticsLabel('Take photo'), findsOneWidget);

    handle.dispose();
  });
}
