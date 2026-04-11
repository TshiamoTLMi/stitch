import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../controllers/wardrobe_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/outfit_result.dart';
import '../../services/caption_service.dart';
import '../../services/outfit_history_service.dart';
import '../../services/outfit_bot_service.dart';

class OutfitGeneratorPage extends StatefulWidget {
  const OutfitGeneratorPage({super.key, required this.userId});

  final String userId;

  @override
  State<OutfitGeneratorPage> createState() => _OutfitGeneratorPageState();
}

class _OutfitGeneratorPageState extends State<OutfitGeneratorPage> {
  static const occasions = ['Work', 'Date', 'Groove', 'Braai', 'Event'];
  static const moods = ['Minimal', 'Clean Drip', 'Street Flex', 'Soft Life'];
  static const weathers = ['Sunny', 'Rainy', 'Cold', 'Hot'];

  final _outfitBot = OutfitBotService();
  final _captionService = CaptionService();
  OutfitResult? _result;
  String? _caption;

  String _occasion = 'Braai';
  String _mood = 'Street Flex';
  String _weather = 'Sunny';

  Future<void> _generate() async {
    final wardrobe = context.read<WardrobeController>().items;
    if (wardrobe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload clothing items first.')));
      return;
    }

    final result = _outfitBot.generate(
      wardrobe: wardrobe,
      occasion: _occasion,
      mood: _mood,
      weather: _weather,
    );

    final caption = _captionService.generate(
      occasion: _occasion,
      mood: _mood,
      weather: _weather,
    );

    setState(() {
      _result = result;
      _caption = caption;
    });

    if (result.isValid) {
      await context.read<OutfitHistoryService>().saveGeneratedOutfit(
        userId: widget.userId,
        occasion: _occasion,
        mood: _mood,
        weather: _weather,
        caption: caption,
        result: result,
      );

      try {
        await FirebaseFirestore.instance.collection('audit_events').add({
          'user_id': widget.userId,
          'type': 'outfit_generated',
          'sprint': 4,
          'message': 'Generated outfit for $_occasion / $_mood / $_weather with score ${result.score}.',
          'created_at': Timestamp.fromDate(DateTime.now()),
        });
      } catch (_) {
        // Audit trail is best-effort in demo mode.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Outfit Choice Bot', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Forecast', style: TextStyle(color: AppTheme.onSurfaceVariant)),
                  SizedBox(height: 4),
                  Text('Johannesburg: 24°C, Sunny', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              Icon(Icons.wb_sunny, color: AppTheme.primary, size: 34),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _occasion,
          decoration: const InputDecoration(labelText: 'Occasion'),
          items: occasions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (value) => setState(() => _occasion = value ?? 'Work'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _mood,
          decoration: const InputDecoration(labelText: 'Mood'),
          items: moods.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (value) => setState(() => _mood = value ?? 'Minimal'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _weather,
          decoration: const InputDecoration(labelText: 'Weather'),
          items: weathers.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (value) => setState(() => _weather = value ?? 'Sunny'),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _generate,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome),
              SizedBox(width: 8),
              Text('Find My Fit'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_result != null)
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Style score: ${_result!.score}/100', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Top: ${_result!.top?.category ?? '-'}'),
                    Text('Bottom: ${_result!.bottom?.category ?? '-'}'),
                    Text('Shoes: ${_result!.shoes?.category ?? '-'}'),
                    Text('Accessory: ${_result!.accessory?.category ?? '-'}'),
                    const SizedBox(height: 12),
                    const Text('Caption Suggestions', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(_caption ?? ''),
                    ),
                    const SizedBox(height: 10),
                    const Text('Reasoning', style: TextStyle(fontWeight: FontWeight.w700)),
                    ..._result!.reasoning.map((e) => Text('- $e')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: 16),
        const Text('Recent Outfit History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 8),
        StreamBuilder<List<OutfitHistoryEntry>>(
          stream: context.read<OutfitHistoryService>().streamRecentHistory(widget.userId, limit: 5),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ));
            }

            final history = snapshot.data!;
            if (history.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No outfit history yet. Generate a fit to start tracking.'),
                ),
              );
            }

            return Column(
              children: history
                  .map(
                    (entry) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.surfaceHighest,
                          child: Text('${entry.score}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        title: Text('${entry.occasion} • ${entry.mood}'),
                        subtitle: Text(
                          '${DateFormat.yMMMd().format(entry.generatedAt)} • ${entry.weather}\n${entry.caption}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
