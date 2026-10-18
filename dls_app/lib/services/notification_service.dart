import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/event_model.dart';

enum ReminderStatus {
  scheduled,
  inAppFallback,
  permissionDenied,
  unavailable,
  cancelled,
  past,
  error,
}

class ReminderResult {
  const ReminderResult({
    required this.eventId,
    required this.status,
    required this.notificationId,
    this.message,
  });

  final String eventId;
  final ReminderStatus status;
  final int notificationId;
  final String? message;
}

/// Handles scheduling and cancelling local push notifications for DLS events.
///
/// Call [init] once at app startup (before runApp). Then call
/// [scheduleEventReminder] after creating an event and
/// [rescheduleAllEvents] on app resume to keep alarms in sync.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  bool? _permissionGranted;
  final Map<String, ReminderResult> _statuses = <String, ReminderResult>{};

  Map<String, ReminderResult> get statuses => Map.unmodifiable(_statuses);

  // ── Android notification channel ──────────────────────────────────────────

  static const _channelId = 'dls_events';
  static const _channelName = 'Event Reminders';
  static const _channelDesc =
      'Outfit and event reminders from Digital Lesela Sete';

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;

    if (kIsWeb) {
      _initialised = true;
      return;
    }

    // Timezone data must be loaded before scheduling.
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Create the Android notification channel once.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );

    _initialised = true;
  }

  // ── Permission request (call on first run / from settings) ────────────────

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (android != null) {
      _permissionGranted = await android.requestNotificationsPermission() ?? false;
      return _permissionGranted!;
    }
    if (ios != null) {
      _permissionGranted = await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      return _permissionGranted!;
    }
    return false;
  }

  // ── Schedule a reminder 1 hour before an event ───────────────────────────

  Future<ReminderResult> scheduleEventReminder(EventModel event) async {
    if (!_initialised) await init();

    final id = notificationIdFor(event.id);
    if (!isNextLocalDay(event.date)) {
      final result = ReminderResult(
        eventId: event.id,
        status: ReminderStatus.unavailable,
        notificationId: id,
        message: 'Reminders are reserved for events on the next local calendar day.',
      );
      _statuses[event.id] = result;
      return result;
    }
    if (kIsWeb) {
      final result = ReminderResult(
        eventId: event.id,
        status: ReminderStatus.inAppFallback,
        notificationId: id,
        message: 'Browser notification delivery is unavailable; this event remains visible in-app.',
      );
      _statuses[event.id] = result;
      return result;
    }

    final reminderTime = event.date.subtract(const Duration(hours: 1));
    final now = DateTime.now();

    if (reminderTime.isBefore(now)) {
      final result = ReminderResult(
        eventId: event.id,
        status: ReminderStatus.past,
        notificationId: id,
      );
      _statuses[event.id] = result;
      return result;
    }

    if (_permissionGranted == null) {
      await requestPermission();
    }
    if (_permissionGranted == false) {
      final result = ReminderResult(
        eventId: event.id,
        status: ReminderStatus.permissionDenied,
        notificationId: id,
        message: 'Notification permission is unavailable. The event remains visible in-app.',
      );
      _statuses[event.id] = result;
      return result;
    }

    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        '${event.name} is in 1 hour',
        'Your outfit is ready. Time to get dressed!',
        tzTime,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      debugPrint('[NOTIF] Scheduled reminder for "${event.name}" at $tzTime');
      final result = ReminderResult(
        eventId: event.id,
        status: ReminderStatus.scheduled,
        notificationId: id,
      );
      _statuses[event.id] = result;
      return result;
    } catch (e) {
      debugPrint('[NOTIF] Could not schedule: $e');
      final result = ReminderResult(
        eventId: event.id,
        status: ReminderStatus.error,
        notificationId: id,
        message: 'Reminder scheduling failed. The event remains visible in-app.',
      );
      _statuses[event.id] = result;
      return result;
    }
  }

  // ── Cancel a specific event's reminder ───────────────────────────────────

  Future<void> cancelEventReminder(EventModel event) async {
    if (!_initialised) await init();
    if (!kIsWeb) await _plugin.cancel(notificationIdFor(event.id));
    _statuses[event.id] = ReminderResult(
      eventId: event.id,
      status: ReminderStatus.cancelled,
      notificationId: notificationIdFor(event.id),
    );
  }

  // ── Cancel all scheduled notifications ───────────────────────────────────

  Future<void> cancelAll() async {
    if (!kIsWeb) await _plugin.cancelAll();
    _statuses.clear();
  }

  // ── Re-schedule all upcoming events (call on app resume / login) ──────────

  Future<void> rescheduleAllEvents(List<EventModel> events) async {
    if (!_initialised) await init();
    await cancelAll();
    for (final e in events.where((event) => isNextLocalDay(event.date))) {
      await scheduleEventReminder(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Stable int ID derived from Firestore doc ID (last 8 hex chars → int).
  static int notificationIdFor(String eventId) {
    var hash = 2166136261;
    for (final codeUnit in eventId.codeUnits) {
      hash = (hash ^ codeUnit) * 16777619 & 0x7FFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }

  static bool isNextLocalDay(DateTime eventDate, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final nextDay = DateTime(reference.year, reference.month, reference.day + 1);
    final followingDay = nextDay.add(const Duration(days: 1));
    return !eventDate.isBefore(nextDay) && eventDate.isBefore(followingDay);
  }

  void _onTap(NotificationResponse response) {
    // Deep-link to Events tab — handled by HomeShell listening to a global
    // event stream in a future iteration.
    debugPrint('[NOTIF] Tapped: ${response.payload}');
  }
}
