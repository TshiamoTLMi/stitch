import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../controllers/wardrobe_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clothing_item.dart';
import '../../models/outfit_result.dart';
import '../../services/caption_service.dart';
import '../../services/outfit_history_service.dart';
import '../../services/outfit_bot_service.dart';
import '../../services/outfit_llm_service.dart';

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
  final _outfitLlmService = OutfitLlmService();
  OutfitResult? _result;
  String? _caption;
  bool _isGenerating = false;
  bool _isAiEnhancing = false;
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  String _occasion = 'Braai';
  String _mood = 'Street Flex';
  String _weather = 'Sunny';

  @override
  void initState() {
    super.initState();
    _bindConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _bindConnectivity() async {
    final current = await _connectivity.checkConnectivity();
    _setOfflineState(current);

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_setOfflineState);
  }

  void _setOfflineState(List<ConnectivityResult> results) {
    final offline = results.isEmpty || results.every((result) => result == ConnectivityResult.none);
    if (!mounted || offline == _isOffline) {
      return;
    }
    setState(() => _isOffline = offline);
  }

  Future<void> _generate() async {
    if (_isGenerating) return;

    final wardrobe = context.read<WardrobeController>().items;
    final readiness = _outfitBot.checkReadiness(wardrobe);
    if (!readiness.canGenerate) {
      final offlineHint = _isOffline
          ? ' You are offline, so only already-synced closet items are available right now.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${readiness.userFriendlyMessage}$offlineHint')),
      );
      return;
    }

    setState(() => _isGenerating = true);

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

    var finalCaption = caption;
    var finalReasoning = <String>[...result.reasoning];

    if (_outfitLlmService.isConfigured && !_isOffline && result.isValid) {
      if (mounted) {
        setState(() => _isAiEnhancing = true);
      }
      final llmInsight = await _outfitLlmService.enhanceOutfit(
        wardrobe: wardrobe,
        result: result,
        occasion: _occasion,
        mood: _mood,
        weather: _weather,
      );
      if (llmInsight != null) {
        finalCaption = llmInsight.caption;
        if (llmInsight.reasoning.isNotEmpty) {
          finalReasoning = llmInsight.reasoning;
        }
      }
      if (mounted) {
        setState(() => _isAiEnhancing = false);
      }
    }

    final finalResult = OutfitResult(
      top: result.top,
      bottom: result.bottom,
      shoes: result.shoes,
      accessory: result.accessory,
      score: result.score,
      reasoning: finalReasoning,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _result = finalResult;
      _caption = finalCaption;
      _isGenerating = false;
    });

    if (finalResult.isValid) {
      unawaited(_persistGeneratedOutfit(result: finalResult, caption: finalCaption));
      if (_isOffline && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generated in offline mode. History will sync automatically when connection returns.'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough matching clean items for this combo. Try another mood or upload more pieces.'),
        ),
      );
    }

    if (mounted && _isAiEnhancing) {
      setState(() => _isAiEnhancing = false);
    }
  }

  Future<void> _persistGeneratedOutfit({required OutfitResult result, required String caption}) async {
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Outfit Choice Bot', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        if (_isOffline) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Offline mode is active. You can still generate outfits from already-synced wardrobe items.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
        ],
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
          onPressed: _isGenerating ? null : _generate,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGenerating) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                const Text('Generating...'),
              ] else ...[
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 8),
                const Text('Find My Fit'),
              ],
            ],
          ),
        ),
        if (_isAiEnhancing) ...[
          const SizedBox(height: 8),
          const Text(
            'AI stylist polishing your fit...',
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ],
        if (!_outfitLlmService.isConfigured) ...[
          const SizedBox(height: 8),
          const Text(
            'Tip: add DLS_LLM_API_KEY to enable Gemini/DeepSeek stylist boost.',
            style: TextStyle(color: AppTheme.onSurfaceVariant),
          ),
        ],
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
                    const Text('Selected Closet Items', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _FitItemChip(label: 'Top', item: _result!.top),
                        _FitItemChip(label: 'Bottom', item: _result!.bottom),
                        _FitItemChip(label: 'Shoes', item: _result!.shoes),
                        _FitItemChip(label: 'Accessory', item: _result!.accessory),
                      ],
                    ),
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

class _FitItemChip extends StatelessWidget {
  const _FitItemChip({required this.label, required this.item});

  final String label;
  final ClothingItem? item;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return Container(
        width: 152,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            const Text('-', style: TextStyle(color: AppTheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final imageUrl = item?.imageUrl ?? '';
    final category = item?.category ?? '';

    return Container(
      width: 152,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 94,
              width: double.infinity,
              child: imageUrl.isEmpty
                  ? const ColoredBox(
                      color: AppTheme.surfaceLow,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined, color: AppTheme.onSurfaceVariant),
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 320,
                      filterQuality: FilterQuality.low,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const ColoredBox(
                              color: AppTheme.surfaceLow,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppTheme.surfaceLow,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined, color: AppTheme.onSurfaceVariant),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.isEmpty ? '-' : category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
