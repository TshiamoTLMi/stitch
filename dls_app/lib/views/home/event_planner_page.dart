import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/wardrobe_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/outfit_bot_service.dart';

class EventPlannerPage extends StatefulWidget {
  const EventPlannerPage({super.key, required this.userId});

  final String userId;

  @override
  State<EventPlannerPage> createState() => _EventPlannerPageState();
}

class _EventPlannerPageState extends State<EventPlannerPage> {
  final _eventNameController = TextEditingController();
  final _bot = OutfitBotService();
  String _occasion = 'Event';
  DateTime _date = DateTime.now().add(const Duration(days: 1));

  static const occasions = ['Work', 'Date', 'Groove', 'Braai', 'Event'];

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

    final event = EventModel(
      id: '',
      userId: widget.userId,
      name: name,
      date: _date,
      occasion: _occasion,
    );

    await context.read<EventService>().createEvent(event);
    _eventNameController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event created.')));
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>().items;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Event Planner', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
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
              ElevatedButton(onPressed: _createEvent, child: const Text('Add Event')),
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
                  child: Text('No upcoming events yet.'),
                ),
              );
            }

            return Column(
              children: events.map((event) {
                final suggestions = _bot.generateSuggestionsForEvent(
                  wardrobe: wardrobe,
                  occasion: event.occasion,
                );

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
                          const Text('Add more clean items to get suggestions.')
                        else
                          ...suggestions.map(
                            (s) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Score ${s.score}: ${s.top?.category ?? '-'} + ${s.bottom?.category ?? '-'} + ${s.shoes?.category ?? '-'}',
                              ),
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
