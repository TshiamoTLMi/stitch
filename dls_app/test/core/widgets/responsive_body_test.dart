import 'package:dls_app/core/widgets/responsive_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the web/desktop viewport audit (SpecKit 001 T033).
///
/// A Flutter Web canvas is the size of the browser window, so the layouts that
/// look fine on a 390px phone can overflow or stretch badly on a 1440px
/// desktop. These tests pin the behaviour at both extremes.
void main() {
  Widget wrap() => MaterialApp(
        home: Scaffold(
          body: ResponsiveBody(
            child: ListView(
              children: <Widget>[
                const Text(
                  'Heading',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < 12; i++)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const SizedBox(width: 40, height: 40),
                      title: Text('Item $i'),
                      subtitle: const Text('A reasonably long subtitle line'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  group('ResponsiveBody', () {
    testWidgets('renders without overflow on a phone viewport', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap());
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow on a desktop browser viewport', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap());
      expect(tester.takeException(), isNull);
    });

    testWidgets('caps content width on a wide viewport', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap());

      final body = tester.widget<ResponsiveBody>(find.byType(ResponsiveBody));
      expect(body.maxWidth, 760);

      // The 760 cap applies to the padded box, so the list itself is 760 - 32.
      final content = tester.getSize(find.byType(ListView));
      expect(content.width, lessThanOrEqualTo(760));
      expect(content.width, closeTo(728, 1));
    });

    testWidgets('leaves narrow viewports at full width', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap());

      // 360 - (16 left + 16 right padding): phones are not letterboxed.
      final content = tester.getSize(find.byType(ListView));
      expect(content.width, closeTo(328, 1));
    });
  });

  group('responsivePagePadding', () {
    testWidgets('uses a tighter gutter on phones and a roomier one on desktop', (tester) async {
      Widget probe(Widget Function(EdgeInsets) child) =>
          MaterialApp(
            home: Builder(
              builder: (context) => child(responsivePagePadding(context)),
            ),
          );

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late EdgeInsets desktop;
      await tester.pumpWidget(probe((p) {
        desktop = p;
        return const SizedBox.shrink();
      }));
      expect(desktop.left, 24);

      tester.view.physicalSize = const Size(390, 844);
      late EdgeInsets phone;
      await tester.pumpWidget(probe((p) {
        phone = p;
        return const SizedBox.shrink();
      }));
      expect(phone.left, 16);
    });
  });
}
