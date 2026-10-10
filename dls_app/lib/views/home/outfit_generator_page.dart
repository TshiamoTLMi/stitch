import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../controllers/wardrobe_controller.dart';
import '../../core/engine/affinity_engine.dart';
import '../../core/engine/candidate_generator.dart';
import '../../core/engine/feedback_store.dart';
import '../../core/engine/outfit_theme.dart';
import '../../core/services/weather_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clothing_item.dart';
import '../../models/outfit.dart';
import '../../models/outfit_result.dart';
import '../../models/weather_context.dart';
import '../../models/weather_location.dart';
import '../../services/caption_service.dart';
import '../../services/outfit_history_service.dart';
import '../../services/outfit_bot_service.dart';
import '../../services/outfit_image_service.dart';
import '../../services/virtual_tryon_service.dart';

class OutfitGeneratorPage extends StatefulWidget {
  const OutfitGeneratorPage({super.key, required this.userId});

  final String userId;

  @override
  State<OutfitGeneratorPage> createState() => _OutfitGeneratorPageState();
}

class _OutfitGeneratorPageState extends State<OutfitGeneratorPage> {
  static const occasions = ['Work', 'Date', 'Groove', 'Braai', 'Event'];
  static const moods = ['Minimal', 'Clean Drip', 'Street Flex', 'Soft Life'];
  static const weathers = ['Hot', 'Warm', 'Mild', 'Cold', 'Freezing', 'Rainy'];

  final _outfitBot = OutfitBotService();
  final _captionService = CaptionService();
  final _outfitImageService = OutfitImageService();
  final _virtualTryOnService = VirtualTryOnService();
  static const String _rulesAsset = 'assets/ml_seed_rules.json';
  AffinityEngine? _affinityEngine;
  CandidateGenerator? _candidateGenerator;
  FeedbackStore? _feedbackStore;
  ScoredOutfit? _scoredOutfit;
  ScoredOutfit? _alternateOutfit;
  String? _alternateWeather;
  String? _engineError;
  OutfitResult? _result;
  Outfit? _engineOutfit;
  String? _caption;
  String? _stylingTip;
  String? _swapSuggestion;
  bool _aiUnavailable = false;
  int _resultVersion = 0;
  bool _isGenerating = false;
  bool _isAiEnhancing = false;
  bool _isRenderingImage = false;
  bool _isGeneratingTryOn = false;
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  String _occasion = 'Braai';
  String _mood = 'Street Flex';
  String _weather = 'Mild';
  OutfitTheme _theme = OutfitTheme.none;

  final _weatherService = WeatherService();
  WeatherContext? _forecast;
  bool _forecastLoading = true;
  // Once the user picks a weather by hand, forecast refreshes stop overriding it.
  bool _weatherTouched = false;

  @override
  void initState() {
    super.initState();
    _bindConnectivity();
    unawaited(_loadAffinityEngine());
    unawaited(_initForecast());
  }

  Future<void> _loadAffinityEngine() async {
    try {
      final engine = await AffinityEngine.fromAsset(_rulesAsset);
      final feedbackStore = FeedbackStore(engine: engine);
      final weights = await feedbackStore.load();
      engine.applyWeights(weights.values);
      if (!mounted) return;
      setState(() {
        _affinityEngine = engine;
        _candidateGenerator = CandidateGenerator(engine: engine);
        _feedbackStore = feedbackStore;
        _engineError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _engineError = 'Styling engine unavailable: $error');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _bindConnectivity() async {
    final current = await _connectivity.checkConnectivity();
    _setOfflineState(current);

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_setOfflineState);
  }

  void _setOfflineState(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    if (!mounted || offline == _isOffline) {
      return;
    }
    setState(() => _isOffline = offline);
  }

  /// Restores the saved city, then loads the forecast for it.
  Future<void> _initForecast() async {
    await _weatherService.loadLocation();
    await _loadForecast();
  }

  Future<void> _loadForecast({bool refresh = false}) async {
    if (refresh && mounted) setState(() => _forecastLoading = true);
    final forecast = await _weatherService.current();
    if (!mounted) return;
    setState(() {
      _forecast = forecast;
      _forecastLoading = false;
      if (!_weatherTouched) _weather = forecast.generatorWeather;
    });
  }

  Future<void> _selectLocation(WeatherLocation location) async {
    await _weatherService.setLocation(location);
    await _loadForecast(refresh: true);
  }

  String _forecastSourceTag(WeatherContext forecast) {
    if (forecast.isLive) return 'Live';
    if (forecast.isCached) return '(cached)';
    return '(default)';
  }

  IconData _forecastIcon(WeatherContext forecast) {
    if (forecast.isRain) return Icons.umbrella;
    if (forecast.condition == 'cold' || forecast.condition == 'freezing') {
      return Icons.ac_unit;
    }
    return Icons.wb_sunny;
  }

  Widget _forecastCard() {
    final forecast = _forecast;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Forecast',
                    style: TextStyle(color: AppTheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  forecast == null
                      ? 'Loading forecast...'
                      : '${forecast.locationLabel} ${_forecastSourceTag(forecast)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh forecast',
            onPressed:
                _forecastLoading ? null : () => _loadForecast(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<WeatherLocation>(
            tooltip: 'Choose city',
            icon: const Icon(Icons.location_on_outlined),
            onSelected: _selectLocation,
            itemBuilder: (context) => [
              for (final place in WeatherLocation.presets)
                PopupMenuItem<WeatherLocation>(
                  value: place,
                  child: Text(place.name),
                ),
            ],
          ),
          Icon(
            forecast == null ? Icons.cloud_queue : _forecastIcon(forecast),
            color: AppTheme.primary,
            size: 34,
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    if (_isGenerating) return;
    if (_engineOutfit != null && _scoredOutfit != null) {
      unawaited(_saveFeedback('regenerated'));
    }

    final generator = _candidateGenerator;
    if (generator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_engineError ?? 'Styling engine is still loading.'),
        ),
      );
      return;
    }

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

    setState(() {
      _isGenerating = true;
      _isAiEnhancing = false;
    });

    final recommendation = generator.recommend(
      wardrobe: wardrobe,
      occasion: _occasion,
      weather: _weather,
      targetStyle: _moodToStyle(_mood),
      theme: _theme,
    );
    final scored = recommendation.primary;
    if (scored == null) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_theme.isActive
                ? 'No clean items match the ${_theme.label} palette for this combo. Add pieces in that palette or pick another theme.'
                : 'Not enough matching clean items for this combo. Try another mood or upload more pieces.'),
          ),
        );
      }
      return;
    }
    final engineOutfit = _toEngineOutfit(scored);
    final finalResult = _toOutfitResult(
      engineOutfit,
      reasoning: <String>[
        ...scored.breakdown.reasons,
        if (engineOutfit.missingItems.isNotEmpty)
          'Missing items: ${engineOutfit.missingItems.join(', ')}.',
      ],
    );
    final finalCaption = _captionService.generate(
      occasion: _occasion,
      mood: _mood,
      weather: _weather,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _result = finalResult;
      _engineOutfit = engineOutfit;
      _scoredOutfit = scored;
      _alternateOutfit = recommendation.alternate;
      _alternateWeather = recommendation.alternateWeather;
      _caption = finalCaption;
      _stylingTip = null;
      _swapSuggestion = null;
      _aiUnavailable = true;
      _resultVersion++;
      _isAiEnhancing = false;
      _isGenerating = false;
    });

    if (finalResult.isValid) {
      unawaited(
          _persistGeneratedOutfit(result: finalResult, caption: finalCaption));
      if (_isOffline && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Generated in offline mode. History will sync automatically when connection returns.'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Not enough matching clean items for this combo. Try another mood or upload more pieces.'),
        ),
      );
    }
  }

  static String? _moodToStyle(String mood) {
    switch (mood) {
      case 'Street Flex':
        return 'streetwear';
      case 'Minimal':
      case 'Clean Drip':
        return 'smart_casual';
      case 'Soft Life':
        return 'casual';
      default:
        return null;
    }
  }

  Outfit _toEngineOutfit(ScoredOutfit scored) {
    ClothingItem? top;
    ClothingItem? bottom;
    ClothingItem? onePiece;
    ClothingItem? outerwear;
    ClothingItem? shoes;
    final accessories = <ClothingItem>[];
    for (final item in scored.items) {
      switch (slotForParentCategory(item.parentCategory)) {
        case OutfitSlot.top:
          top ??= item;
        case OutfitSlot.bottom:
          bottom ??= item;
        case OutfitSlot.onePiece:
          onePiece ??= item;
        case OutfitSlot.outerwear:
          outerwear ??= item;
        case OutfitSlot.shoes:
          shoes ??= item;
        case OutfitSlot.accessory:
          accessories.add(item);
      }
    }
    return Outfit(
      top: top,
      bottom: bottom,
      onePiece: onePiece,
      outerwear: outerwear,
      shoes: shoes,
      accessories: accessories,
      styleScore: scored.styleMatchPercent,
      reason: scored.reason,
    );
  }

  OutfitResult _toOutfitResult(Outfit outfit,
      {required List<String> reasoning}) {
    return OutfitResult(
      top: outfit.top,
      bottom: outfit.bottom,
      shoes: outfit.shoes,
      accessory: outfit.accessories.isEmpty ? null : outfit.accessories.first,
      outerwear: outfit.outerwear,
      onePiece: outfit.onePiece,
      accessories: outfit.accessories,
      score: outfit.styleScore,
      reasoning: reasoning,
    );
  }

  Future<void> _saveFeedback(String reason) async {
    final store = _feedbackStore;
    final scored = _scoredOutfit;
    if (store == null || scored == null || reason == 'regenerated') return;
    try {
      final weights = await store.applyFeedback(
        contributions: scored.contributionKeys,
        feedback: reason == 'accepted' ? 1.0 : 0.0,
      );
      _affinityEngine?.applyWeights(weights.values);
    } catch (_) {
      // Feedback is best-effort while local storage is unavailable.
    }
  }

  Future<void> _wearThis() async {
    await _saveFeedback('accepted');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to your lookbook.')),
      );
    }
  }

  Future<void> _swapItem() async {
    await _saveFeedback('user_swap');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Swap noted. We will learn your preference.')),
      );
    }
  }

  Future<void> _persistGeneratedOutfit(
      {required OutfitResult result, required String caption}) async {
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
        'message':
            'Generated outfit for $_occasion / $_mood / $_weather with score ${result.score}.',
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      // Audit trail is best-effort in demo mode.
    }
  }

  Future<void> _generateOutfitImage() async {
    final result = _result;
    if (result == null || !result.isValid || _isRenderingImage) {
      return;
    }

    setState(() => _isRenderingImage = true);
    try {
      final bytes = await _outfitImageService.composeOutfitImage(
        result: result,
        title: _caption,
        cleanupBackground: true,
      );
      if (!mounted) {
        return;
      }
      await _showGeneratedImageDialog(
        title: 'Generated Outfit Image',
        bytes: bytes,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Could not generate outfit image. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRenderingImage = false);
      }
    }
  }

  Future<void> _generateTryOn() async {
    final result = _result;
    if (result == null || !result.isValid || _isGeneratingTryOn) {
      return;
    }

    if (!_virtualTryOnService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Try-on backend is not configured. Add DLS_TRYON_ENDPOINT to enable this feature.'),
        ),
      );
      return;
    }

    setState(() => _isGeneratingTryOn = true);
    try {
      final imageUrl = await _virtualTryOnService.generateTryOnImage(
        result: result,
        occasion: _occasion,
        mood: _mood,
        weather: _weather,
      );

      if (!mounted) {
        return;
      }

      if (imageUrl == null || imageUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Try-on service did not return an image.')),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Virtual Try-On (Beta)'),
            content: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return const SizedBox(
                    width: 280,
                    height: 320,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 280,
                  height: 320,
                  child: Center(child: Text('Could not load try-on image.')),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Try-on generation failed. Please retry.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingTryOn = false);
      }
    }
  }

  Future<void> _showGeneratedImageDialog({
    required String title,
    required Uint8List bytes,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: 280,
              height: 360,
              fit: BoxFit.cover,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _alternateWeatherLabel(String? condition) {
    switch (condition) {
      case 'rain':
        return 'Rainy';
      case 'mild':
        return 'Mild';
      default:
        return condition ?? '';
    }
  }

  /// Backup outfit for the contrasting weather condition.
  Widget _alternateCard() {
    final alternate = _alternateOutfit!;
    final weatherLabel = _alternateWeatherLabel(_alternateWeather);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horizontal_circle_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Backup for $weatherLabel weather',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${alternate.styleMatchPercent}/100'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in alternate.items)
                Chip(label: Text(item.category)),
            ],
          ),
          if (alternate.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(alternate.reason),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Outfit Choice Bot',
            style: Theme.of(context).textTheme.headlineMedium),
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
        _forecastCard(),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _occasion,
          decoration: const InputDecoration(labelText: 'Occasion'),
          items: occasions
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (value) => setState(() => _occasion = value ?? 'Work'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _mood,
          decoration: const InputDecoration(labelText: 'Mood'),
          items: moods
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (value) => setState(() => _mood = value ?? 'Minimal'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _weather,
          decoration: const InputDecoration(labelText: 'Weather'),
          items: weathers
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (value) => setState(() {
            _weather = value ?? _weather;
            _weatherTouched = true;
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<OutfitTheme>(
          initialValue: _theme,
          decoration: const InputDecoration(labelText: 'Theme'),
          items: OutfitTheme.values
              .map((theme) =>
                  DropdownMenuItem(value: theme, child: Text(theme.label)))
              .toList(),
          onChanged: (value) =>
              setState(() => _theme = value ?? OutfitTheme.none),
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
            style: TextStyle(
                color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ],
        if (_aiUnavailable) ...[
          const SizedBox(height: 8),
          const Text(
            'Using basic mode. AI stylist unavailable.',
            style: TextStyle(color: AppTheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        if (_result != null)
          Column(
            children: [
              Dismissible(
                key: ValueKey('outfit-$_resultVersion'),
                direction: DismissDirection.horizontal,
                onDismissed: (direction) {
                  if (direction == DismissDirection.startToEnd) {
                    unawaited(_wearThis());
                  } else {
                    unawaited(_generate());
                  }
                },
                background: const ColoredBox(
                  color: Color(0xFFB8E6C1),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 20),
                      child: Icon(Icons.check_circle_outline),
                    ),
                  ),
                ),
                secondaryBackground: const ColoredBox(
                  color: Color(0xFFFFD8D0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 20),
                      child: Icon(Icons.refresh),
                    ),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Style score: ${_result!.score}/100',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Top: ${_result!.top?.category ?? '-'}'),
                      Text('Bottom: ${_result!.bottom?.category ?? '-'}'),
                      Text('One-piece: ${_result!.onePiece?.category ?? '-'}'),
                      Text('Shoes: ${_result!.shoes?.category ?? '-'}'),
                      Text('Outerwear: ${_result!.outerwear?.category ?? '-'}'),
                      Text('Accessory: ${_result!.accessory?.category ?? '-'}'),
                      const SizedBox(height: 12),
                      const Text('Selected Closet Items',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _FitItemChip(label: 'Top', item: _result!.top),
                          _FitItemChip(label: 'Bottom', item: _result!.bottom),
                            _FitItemChip(
                              label: 'One-piece', item: _result!.onePiece),
                          _FitItemChip(label: 'Shoes', item: _result!.shoes),
                          _FitItemChip(
                              label: 'Outerwear', item: _result!.outerwear),
                          _FitItemChip(
                              label: 'Accessory', item: _result!.accessory),
                          ..._result!.accessories.skip(1).take(1).map(
                                (item) => _FitItemChip(
                                    label: 'Accessory 2', item: item),
                              ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Caption Suggestions',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(_caption ?? ''),
                      ),
                      if ((_stylingTip ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('Styling Tip',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceHigh,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(_stylingTip!),
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Text('Reasoning',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      ..._result!.reasoning.map((e) => Text('- $e')),
                    ],
                  ),
                ),
              ),
              if (_alternateOutfit != null) ...[
                const SizedBox(height: 10),
                _alternateCard(),
              ],
              if (_swapSuggestion != null) ...[
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: const Text('AI suggests a swap'),
                    subtitle: Text(_swapSuggestion!),
                    trailing: TextButton(
                      onPressed: _swapItem,
                      child: const Text('Apply Swap'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _wearThis,
                      icon: const Icon(Icons.checkroom_outlined),
                      label: const Text('Wear This'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _swapItem,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Swap Item'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                      onPressed:
                          _isRenderingImage ? null : _generateOutfitImage,
                      icon: _isRenderingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined),
                      label: Text(_isRenderingImage
                          ? 'Rendering...'
                          : 'Generate Image'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGeneratingTryOn ? null : _generateTryOn,
                  icon: _isGeneratingTryOn
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high_outlined),
                  label: Text(_isGeneratingTryOn
                      ? 'Generating Try-On...'
                      : 'Virtual Try-On (Beta)'),
                ),
              ),
              if (!_virtualTryOnService.isConfigured) ...[
                const SizedBox(height: 8),
                const Text(
                  'Tip: add DLS_TRYON_ENDPOINT to enable backend try-on rendering.',
                  style: TextStyle(color: AppTheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        const SizedBox(height: 16),
        const Text('Recent Outfit History',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 8),
        StreamBuilder<List<OutfitHistoryEntry>>(
          stream: context
              .read<OutfitHistoryService>()
              .streamRecentHistory(widget.userId, limit: 5),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ));
            }

            final history = snapshot.data!;
            if (history.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                      'No outfit history yet. Generate a fit to start tracking.'),
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
                          child: Text('${entry.score}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
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
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AppTheme.onSurfaceVariant),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppTheme.surfaceLow,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: AppTheme.onSurfaceVariant),
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
