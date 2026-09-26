import 'package:dls_app/models/event_model.dart';
import 'package:dls_app/services/event_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects only the next local calendar day in deterministic order', () {
    final now = DateTime(2026, 9, 26, 18);
    final events = <EventModel>[
      EventModel(id: 'later', userId: 'redacted', name: 'Later', date: DateTime(2026, 9, 28), occasion: 'Event'),
      EventModel(id: 'tomorrow-late', userId: 'redacted', name: 'Late', date: DateTime(2026, 9, 27, 20), occasion: 'Event'),
      EventModel(id: 'tomorrow-early', userId: 'redacted', name: 'Early', date: DateTime(2026, 9, 27, 8), occasion: 'Work'),
    ];

    final nextDay = EventService.nextLocalDayEvents(events, now: now);

    expect(nextDay.map((event) => event.id), orderedEquals(<String>['tomorrow-early', 'tomorrow-late']));
  });
}