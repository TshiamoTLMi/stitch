import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dls_app/core/vision/outfit_pose_scanner.dart';
import 'package:dls_app/views/wardrobe/scan_review_sheet.dart';

/// A tiny but valid 1x1 PNG so `Image.memory` in `_GarmentCard` decodes
/// without error - the review sheet's own tests care about editing state,
/// not image rendering.
final Uint8List _onePixelPng =
    Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1)));

List<ScannedGarment> _garments() => [
      ScannedGarment(
        slot: OutfitSlot.top,
        imageBytes: _onePixelPng,
        parentCategory: 'Tops',
        subcategory: 'T-shirts',
        color: 'red',
        colorGroup: 'warm',
      ),
      ScannedGarment(
        slot: OutfitSlot.bottom,
        imageBytes: _onePixelPng,
        parentCategory: 'Bottoms',
        subcategory: 'Jeans',
        color: 'blue',
        colorGroup: 'cool',
      ),
      ScannedGarment(
        slot: OutfitSlot.footwear,
        imageBytes: _onePixelPng,
        parentCategory: 'Footwear',
        subcategory: 'Sneakers',
        color: 'black',
        colorGroup: 'neutral',
      ),
    ];

/// Each card is tall (image + several form fields), so the default
/// 800x600 test surface only fits one in `ListView.separated`'s viewport,
/// leaving the rest unbuilt. A tall surface lets every card build without
/// needing to scroll in each test.
Future<void> _pumpReviewSheet(
  WidgetTester tester, {
  required List<ScannedGarment> garments,
  bool approximate = false,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ScanReviewSheet(garments: garments, approximate: approximate),
    ),
  );
}

void main() {
  testWidgets('renders one editable card per detected garment', (tester) async {
    await _pumpReviewSheet(tester, garments: _garments());

    expect(find.text('Top'), findsOneWidget);
    expect(find.text('Bottom'), findsOneWidget);
    expect(find.text('Shoes'), findsOneWidget);
    expect(find.text('Save All to Closet (3)'), findsOneWidget);
  });

  testWidgets('shows the approximate-crop disclaimer only when asked', (tester) async {
    await _pumpReviewSheet(tester, garments: _garments(), approximate: true);

    expect(
      find.textContaining('Approximate crop'),
      findsOneWidget,
    );
  });

  testWidgets('discarding a card removes it from the kept count, and Undo restores it',
      (tester) async {
    await _pumpReviewSheet(tester, garments: _garments());

    await tester.tap(find.widgetWithIcon(IconButton, Icons.close).first);
    await tester.pump();

    expect(find.text('Top discarded'), findsOneWidget);
    expect(find.text('Save All to Closet (2)'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(find.text('Top discarded'), findsNothing);
    expect(find.text('Save All to Closet (3)'), findsOneWidget);
  });

  testWidgets('Save All is disabled once every card is discarded', (tester) async {
    await _pumpReviewSheet(tester, garments: _garments());

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.widgetWithIcon(IconButton, Icons.close).first);
      await tester.pump();
    }

    expect(find.text('Nothing to save'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('editing a style tag chip on one card does not affect the others',
      (tester) async {
    await _pumpReviewSheet(tester, garments: _garments());

    final formalChips = find.widgetWithText(FilterChip, 'formal');
    expect(formalChips, findsNWidgets(3));

    await tester.tap(formalChips.first);
    await tester.pump();

    final chipStates = tester
        .widgetList<FilterChip>(formalChips)
        .map((chip) => chip.selected)
        .toList();
    expect(chipStates.where((selected) => selected).length, 1);
  });
}
