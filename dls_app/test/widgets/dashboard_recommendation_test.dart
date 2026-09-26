import 'package:dls_app/models/clothing_item.dart';
import 'package:dls_app/models/event_model.dart';
import 'package:dls_app/views/home/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ClothingItem item({required String categoryType, required String category}) {
    final now = DateTime(2026, 1, 1);
    return ClothingItem(
      id: category,
      parentCategory: 'Tops',
      subcategory: category,
      categoryType: categoryType,
      color: 'black',
      colorGroup: 'neutral',
      styleTags: const <String>['casual'],
      season: 'All Season',
      status: 'clean',
      gender: 'Unisex',
      imageUrl: '',
      userId: 'user-redacted',
      createdAt: now,
      updatedAt: now,
    );
  }

  EventModel event({required String occasion}) {
    return EventModel(
      id: 'event-redacted',
      userId: 'user-redacted',
      name: 'Tomorrow event',
      date: DateTime(2026, 1, 2, 18),
      occasion: occasion,
    );
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required List<ClothingItem> wardrobe,
    required EventModel event,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(
            userId: 'user-redacted',
            wardrobeItems: wardrobe,
            upcomingEventsStream: Stream<List<EventModel>>.value(<EventModel>[event]),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows event context, reason, and wardrobe action', (tester) async {
    await pumpDashboard(
      tester,
      wardrobe: <ClothingItem>[item(categoryType: 'top', category: 'shirt')],
      event: event(occasion: 'Work'),
    );

    expect(find.textContaining(' · Jan 2, 2026 · Work'), findsOneWidget);
    expect(find.textContaining('Work occasion'), findsNWidgets(3));
    expect(find.text('Formal shoes'), findsOneWidget);
    expect(find.text('Add to wardrobe'), findsNWidgets(2));
  });

  testWidgets('shows a covered state when the wardrobe meets the need', (tester) async {
    await pumpDashboard(
      tester,
      wardrobe: <ClothingItem>[
        item(categoryType: 'shoes', category: 'shoes'),
        item(categoryType: 'accessory', category: 'belt'),
        item(categoryType: 'top', category: 'shirt'),
      ],
      event: event(occasion: 'Work'),
    );

    expect(find.textContaining('wardrobe covers this need'), findsNWidgets(3));
    expect(find.text('Generate an outfit'), findsNWidgets(3));
  });

  testWidgets('does not fabricate a need for an unsupported occasion', (tester) async {
    await pumpDashboard(
      tester,
      wardrobe: const <ClothingItem>[],
      event: event(occasion: 'Unknown occasion'),
    );

    expect(find.text('Event details'), findsOneWidget);
    expect(find.text('Needs more data'), findsOneWidget);
    expect(find.text('Add to wardrobe'), findsNothing);
  });
}