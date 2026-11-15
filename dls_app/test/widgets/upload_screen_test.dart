import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dls_app/views/upload_screen.dart';

void main() {
  testWidgets('builds with no vision/AI dependency and no decorative AI chrome',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UploadScreen()));
    await tester.pump();

    // Screen renders without requiring a VisionEngine to be supplied.
    expect(find.byType(UploadScreen), findsOneWidget);
    expect(find.text('LESÉLA SETE'), findsOneWidget);

    // The decorative "AI thinking" affordances tied to the removed
    // GeminiVisionEngine must not exist anywhere in the tree.
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    expect(find.textContaining('TYPE:'), findsNothing);
    expect(find.textContaining('TEXTURE:'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // Manual capture controls remain available with no image selected yet.
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });
}
