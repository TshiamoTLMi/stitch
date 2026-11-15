import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dls_app/views/auth/onboarding_screen.dart';

void main() {
  testWidgets(
      'First Name -> Last Name -> Nickname chain focus via the keyboard '
      '"next" action, and Nickname dismisses the keyboard on "done"',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    final firstNameField =
        find.widgetWithText(TextField, 'First Name *').first;
    final lastNameField = find.widgetWithText(TextField, 'Last Name *').first;
    final nicknameField =
        find.widgetWithText(TextField, 'Display Name / Nickname').first;

    await tester.tap(firstNameField);
    await tester.pump();
    expect(tester.widget<TextField>(firstNameField).textInputAction,
        TextInputAction.next);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(lastNameField).focusNode!.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
        tester.widget<TextField>(nicknameField).focusNode!.hasFocus, isTrue);
    expect(tester.widget<TextField>(nicknameField).textInputAction,
        TextInputAction.done);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
        tester.widget<TextField>(nicknameField).focusNode!.hasFocus, isFalse);
  });
}
