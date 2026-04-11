import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/event_model.dart';

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

  // ── Android notification channel ──────────────────────────────────────────

  static const _channelId = 'dls_events';
  static const _channelName = 'Event Reminders';
  static const _channelDesc =
      'Outfit and event reminders from Digital Lesela Sete';

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;

    // Timezone data must be loaded before scheduling.
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
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
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return false;
  }

  // ── Schedule a reminder 1 hour before an event ───────────────────────────

  Future<void> scheduleEventReminder(EventModel event) async {
    if (!_initialised) await init();

    final reminderTime = event.date.subtract(const Duration(hours: 1));
    final now = DateTime.now();

    if (reminderTime.isBefore(now)) return; // already past — skip

    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);
    final id = _idFromEvent(event);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
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
        '${event.name} is in 1 hour 🕐',
        'Your outfit is ready. Time to get dressed!',
        tzTime,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      debugPrint('[NOTIF] Scheduled reminder for "${event.name}" at $tzTime');
    } catch (e) {
      debugPrint('[NOTIF] Could not schedule: $e');
    }
  }

  // ── Cancel a specific event's reminder ───────────────────────────────────

  Future<void> cancelEventReminder(EventModel event) async {
    await _plugin.cancel(_idFromEvent(event));
  }

  // ── Cancel all scheduled notifications ───────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Re-schedule all upcoming events (call on app resume / login) ──────────

  Future<void> rescheduleAllEvents(List<EventModel> events) async {
    if (!_initialised) await init();
    await cancelAll();
    for (final e in events) {
      await scheduleEventReminder(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Stable int ID derived from Firestore doc ID (last 8 hex chars → int).
  int _idFromEvent(EventModel event) {
    final hex = event.id.replaceAll('-', '');
    final tail = hex.length > 8 ? hex.substring(hex.length - 8) : hex;
    return int.tryParse(tail, radix: 16) ?? event.id.hashCode.abs() % 0x7FFFFFFF;
  }

  void _onTap(NotificationResponse response) {
    // Deep-link to Events tab — handled by HomeShell listening to a global
    // event stream in a future iteration.
    debugPrint('[NOTIF] Tapped: ${response.payload}');
  }
}
