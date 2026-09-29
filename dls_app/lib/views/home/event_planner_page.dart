import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../controllers/wardrobe_controller.dart';
import '../../core/services/event_outfit_suggester.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clothing_item.dart';
import '../../models/event_model.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/event_service.dart';
import '../../services/outfit_bot_service.dart';
import '../../widgets/context_tip_card.dart';

class EventPlannerPage extends StatefulWidget {
  const EventPlannerPage({super.key, required this.userId});

  final String userId;

  @override
  State<EventPlannerPage> createState() => _EventPlannerPageState();
}

class _EventPlannerPageState extends State<EventPlannerPage> {
  final _eventNameController = TextEditingController();
  EventOutfitSuggester? _suggester;
  // Readiness banner only -- not a scoring path.
  final _readinessBot = OutfitBotService();
  final _calendarSync = CalendarSyncService();
  String _occasion = 'Event';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _importingCalendar = false;

  static const occasions = ['Work', 'Date', 'Groove', 'Braai', 'Event'];

  @override
  void initState() {
    super.initState();
    // Sprint 9: pre-load the on-device affinity engine for event suggestions.
    _loadSuggester();
  }

  Future<void> _loadSuggester() async {
    try {
      final suggester = await EventOutfitSuggester.load();
      if (mounted) setState(() => _suggester = suggester);
    } catch (_) {
      // Suggestions stay empty until the matrix can be read.
    }
  }

  /// Engine-backed suggestions; falls back to nothing rather than a legacy path.
  List<String> _suggestionsFor(
    EventModel event,
    List<ClothingItem> items,
  ) {
    if (event.recommendedOutfits.isNotEmpty) return event.recommendedOutfits;
    return _suggester?.suggest(
          wardrobe: items,
          occasion: event.occasion,
        ) ??
        const <String>[];
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    super.dispose();
  }

  Future<void> _createEvent() async {
    final name = _eventNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter event name.')));
      return;
    }

    final wardrobe = context.read<WardrobeController>().items;
    final suggestions = _suggester?.suggest(
          wardrobe: wardrobe,
          occasion: _occasion,
        ) ??
        const <String>[];

    final event = EventModel(
      id: '',
      userId: widget.userId,
      name: name,
      date: _date,
      occasion: _occasion,
      recommendedOutfits: suggestions,
    );

    await context.read<EventService>().createEvent(event);
    try {
      await FirebaseFirestore.instance.collection('audit_events').add({
        'user_id': widget.userId,
        'type': 'event_created',
        'sprint': 5,
        'message': 'Created event "$name" with ${event.recommendedOutfits.length} recommendation(s).',
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      // Audit trail is best-effort in demo mode.
    }
    _eventNameController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event created.')));
  }

  Future<void> _importFromPhoneCalendar() async {
    if (_importingCalendar) return;
    setState(() => _importingCalendar = true);

    try {
      final result = await _calendarSync.importUpcomingEvents(
        userId: widget.userId,
        eventService: context.read<EventService>(),
        daysAhead: 120,
      );

      if (!mounted) return;
      if (!result.permissionGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calendar permission denied. Enable it to sync events.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Calendar sync done: ${result.imported} imported, ${result.skipped} skipped, ${result.failed} failed.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar sync failed. Please retry.')),
      );
    } finally {
      if (mounted) setState(() => _importingCalendar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>().items;
    final readiness = _readinessBot.checkReadiness(wardrobe);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Event Planner', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        ContextTipCard(
          title: readiness.canGenerate ? 'Planner Ready' : 'Planner Needs More Closet Data',
          message: readiness.canGenerate
              ? 'Create events and the app will suggest looks from your clean wardrobe items.'
              : '${readiness.userFriendlyMessage} Add more pieces to unlock stronger event recommendations.',
          icon: readiness.canGenerate ? Icons.event_available_outlined : Icons.event_busy_outlined,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              TextField(
                controller: _eventNameController,
                decoration: const InputDecoration(labelText: 'Event name'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _occasion,
                decoration: const InputDecoration(labelText: 'Occasion'),
                items: occasions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) => setState(() => _occasion = value ?? 'Event'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text('Date: ${DateFormat.yMMMd().format(_date)}')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: _date,
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                      }
                    },
                    child: const Text('Pick date'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _createEvent,
                      child: const Text('Add Event'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _importingCalendar ? null : _importFromPhoneCalendar,
                      icon: _importingCalendar
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calendar_month_outlined),
                      label: Text(_importingCalendar ? 'Importing...' : 'Import Phone Calendar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('Upcoming Events', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 8),
        StreamBuilder<List<EventModel>>(
          stream: context.read<EventService>().streamUpcomingEvents(widget.userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = snapshot.data!;
            if (events.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No upcoming events yet. Add one above or import from your phone calendar.'),
                ),
              );
            }

            return Column(
              children: events.map((event) {
                final suggestions = _suggestionsFor(event, wardrobe);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.name, style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${DateFormat.yMMMd().format(event.date)} | ${event.occasion}',
                          style: const TextStyle(color: AppTheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        if (suggestions.isEmpty)
                          const Text('Add more clean wardrobe items to unlock better event suggestions.')
                        else
                          ...suggestions.map(
                            (s) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(s),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
