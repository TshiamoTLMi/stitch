import 'package:device_calendar/device_calendar.dart';

import '../models/event_model.dart';
import 'event_service.dart';

class CalendarImportResult {
  const CalendarImportResult({
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.permissionGranted,
  });

  final int imported;
  final int skipped;
  final int failed;
  final bool permissionGranted;
}

class CalendarSyncService {
  final DeviceCalendarPlugin _calendar = DeviceCalendarPlugin();

  Future<CalendarImportResult> importUpcomingEvents({
    required String userId,
    required EventService eventService,
    int daysAhead = 90,
  }) async {
    final hasPermission = await _ensurePermission();
    if (!hasPermission) {
      return const CalendarImportResult(
        imported: 0,
        skipped: 0,
        failed: 0,
        permissionGranted: false,
      );
    }

    final now = DateTime.now();
    final end = now.add(Duration(days: daysAhead));

    final calendarsResult = await _calendar.retrieveCalendars();
    final calendars = calendarsResult.data ?? const <Calendar>[];

    var imported = 0;
    var skipped = 0;
    var failed = 0;

    for (final cal in calendars) {
      final calId = cal.id;
      if (calId == null || calId.isEmpty) continue;

      try {
        final eventsResult = await _calendar.retrieveEvents(
          calId,
          RetrieveEventsParams(
            startDate: now,
            endDate: end,
          ),
        );

        final events = eventsResult.data ?? const <Event>[];
        for (final phoneEvent in events) {
          final title = (phoneEvent.title ?? '').trim();
          final start = phoneEvent.start;
          if (title.isEmpty || start == null) {
            skipped++;
            continue;
          }

          final sourceKey =
              'phone:$calId:${phoneEvent.eventId ?? title}:${start.toIso8601String()}';

          final mapped = EventModel(
            id: '',
            userId: userId,
            name: title,
            date: start.toLocal(),
            occasion: _mapOccasion(title),
            recommendedOutfits: const <String>[],
            source: 'phone_calendar',
            sourceKey: sourceKey,
          );

          final created = await eventService.createEventIfMissing(mapped);
          if (created) {
            imported++;
          } else {
            skipped++;
          }
        }
      } catch (_) {
        failed++;
      }
    }

    return CalendarImportResult(
      imported: imported,
      skipped: skipped,
      failed: failed,
      permissionGranted: true,
    );
  }

  Future<bool> _ensurePermission() async {
    final current = await _calendar.hasPermissions();
    final currentGranted = current.data ?? false;
    if (currentGranted) return true;

    final requested = await _calendar.requestPermissions();
    return requested.data ?? false;
  }

  String _mapOccasion(String title) {
    final t = title.toLowerCase();
    if (t.contains('meeting') || t.contains('office') || t.contains('work')) {
      return 'Work';
    }
    if (t.contains('date') || t.contains('anniversary')) {
      return 'Date';
    }
    if (t.contains('party') || t.contains('concert') || t.contains('club')) {
      return 'Groove';
    }
    if (t.contains('braai')) {
      return 'Braai';
    }
    return 'Event';
  }
}
