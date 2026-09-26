import 'package:dls_app/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification identity is stable and event-derived', () {
    final first = NotificationService.notificationIdFor('event-redacted');
    final second = NotificationService.notificationIdFor('event-redacted');

    expect(first, greaterThan(0));
    expect(second, first);
    expect(NotificationService.notificationIdFor('other-event'), isNot(first));
  });

  test('reminder status distinguishes in-app fallback from delivery', () {
    const result = ReminderResult(
      eventId: 'event-redacted',
      status: ReminderStatus.inAppFallback,
      notificationId: 1,
      message: 'Browser notification delivery is unavailable.',
    );

    expect(result.status, ReminderStatus.inAppFallback);
    expect(result.message, contains('unavailable'));
  });

  test('current reminders are limited to the next local calendar day', () {
    final now = DateTime(2026, 9, 26, 18);

    expect(
      NotificationService.isNextLocalDay(DateTime(2026, 9, 27, 8), now: now),
      isTrue,
    );
    expect(
      NotificationService.isNextLocalDay(DateTime(2026, 9, 26, 23), now: now),
      isFalse,
    );
    expect(
      NotificationService.isNextLocalDay(DateTime(2026, 9, 28), now: now),
      isFalse,
    );
  });

  test('reminder result exposes cancellation without claiming delivery', () {
    const result = ReminderResult(
      eventId: 'event-redacted',
      status: ReminderStatus.cancelled,
      notificationId: 7,
    );

    expect(result.status, ReminderStatus.cancelled);
    expect(result.message, isNull);
  });
}