import 'package:dls_app/models/profile_analytics_state.dart';
import 'package:dls_app/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics mapping deduplicates clothing and keeps unavailable score null', () {
    final state = ProfileService.analyticsFromRecords(
      clothingRecords: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'item-1', 'subcategory': 'formal_shirt'},
        <String, dynamic>{'id': 'item-1', 'subcategory': 'formal_shirt'},
      ],
      outfitRecords: const <Map<String, dynamic>>[],
      eventRecords: const <Map<String, dynamic>>[],
      auditRecords: const <Map<String, dynamic>>[],
    );

    expect(state.status, AnalyticsStatus.ready);
    expect(state.itemCount, 1);
    expect(state.styleScore, isNull);
    expect(state.topCategory, 'Formal Shirt');
  });

  test('timeline mapping is readable and newest first', () {
    final timeline = ProfileService.styleEvolutionFromRecords(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'event_created',
          'message': '',
          'createdAt': DateTime(2026, 1, 1),
        },
        <String, dynamic>{
          'type': 'outfit_generated',
          'message': 'A saved look',
          'createdAt': DateTime(2026, 1, 2),
        },
      ],
    );

    expect(timeline.first.label, 'Outfit generated');
    expect(timeline.last.description, 'Event created');
  });

  test('failed reads are error or partial, never complete fabricated analytics', () {
    final state = ProfileService.analyticsFromRecords(
      clothingRecords: const <Map<String, dynamic>>[],
      outfitRecords: const <Map<String, dynamic>>[],
      eventRecords: const <Map<String, dynamic>>[],
      auditRecords: const <Map<String, dynamic>>[],
      hadReadError: true,
    );

    expect(state.status, AnalyticsStatus.error);
    expect(state.itemCount, 0);
    expect(state.styleScore, isNull);
    expect(state.canRetry, isTrue);
  });
}