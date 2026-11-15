import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dls_app/views/onboarding/value_prop_carousel.dart';

void main() {
  testWidgets('shows the first slide and a Skip that is always enabled',
      (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(home: ValuePropCarousel(onDone: () => done = true)),
    );

    expect(find.text('Snap Your Outfit'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(done, isTrue);
  });

  testWidgets('Next advances through all 3 slides, then shows Get Started',
      (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(home: ValuePropCarousel(onDone: () => done = true)),
    );

    expect(find.text('Snap Your Outfit'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Smart Offline Styling'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Track Your Wardrobe'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pump();
    expect(done, isTrue);
  });
}
