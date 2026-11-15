import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dls_app/views/auth/guided_first_action_screen.dart';

void main() {
  testWidgets('renders both guided actions and a skip option', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GuidedFirstActionScreen(userId: 'uid-1', onComplete: () {}),
      ),
    );

    expect(find.text('Scan a Full-Body Photo'), findsOneWidget);
    expect(find.text('Load Demo Wardrobe'), findsOneWidget);
    expect(find.text("I'll do this later"), findsOneWidget);
  });

  testWidgets('tapping "Load Demo Wardrobe" invokes the seed action once '
      'with this user\'s id, then completes', (tester) async {
    var seedCalls = 0;
    String? seededUserId;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: GuidedFirstActionScreen(
          userId: 'uid-42',
          seedAction: (userId) async {
            seedCalls++;
            seededUserId = userId;
          },
          onComplete: () => completed = true,
        ),
      ),
    );

    await tester.tap(find.text('Load Demo Wardrobe'));
    await tester.pumpAndSettle();

    expect(seedCalls, 1);
    expect(seededUserId, 'uid-42');
    expect(completed, isTrue);
  });

  testWidgets('a seed failure still completes rather than trapping the user',
      (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: GuidedFirstActionScreen(
          userId: 'uid-1',
          seedAction: (_) async => throw Exception('network error'),
          onComplete: () => completed = true,
        ),
      ),
    );

    await tester.tap(find.text('Load Demo Wardrobe'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('tapping "Scan a Full-Body Photo" invokes the scan action, '
      'then completes, without the real scanner/camera ever running',
      (tester) async {
    var scanCalls = 0;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: GuidedFirstActionScreen(
          userId: 'uid-1',
          scanAction: (context) async {
            scanCalls++;
          },
          onComplete: () => completed = true,
        ),
      ),
    );

    await tester.tap(find.text('Scan a Full-Body Photo'));
    await tester.pumpAndSettle();

    expect(scanCalls, 1);
    expect(completed, isTrue);
  });

  testWidgets('"I\'ll do this later" completes without invoking either action',
      (tester) async {
    var seedCalls = 0;
    var scanCalls = 0;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: GuidedFirstActionScreen(
          userId: 'uid-1',
          seedAction: (_) async => seedCalls++,
          scanAction: (_) async => scanCalls++,
          onComplete: () => completed = true,
        ),
      ),
    );

    await tester.tap(find.text("I'll do this later"));
    await tester.pumpAndSettle();

    expect(seedCalls, 0);
    expect(scanCalls, 0);
    expect(completed, isTrue);
  });
}
