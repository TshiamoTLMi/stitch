import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/weather_context.dart';
import '../../models/weather_location.dart';
import '../storage/kv_store.dart';

/// Fetches local weather from the free Open-Meteo REST API and maps it into the
/// DLS engine's condition vocabulary.
///
/// Offline strategy:
/// 1. Live request succeeds -> map, cache atomically, return.
/// 2. Network error/timeout/bad payload -> read `cached_weather.json`.
/// 3. No cache -> neutral default (22°C, `warm`, dry).
///
/// `geolocator` is intentionally not a dependency, so the default coordinates are
/// used (Johannesburg, matching the existing weather card in the UI).
class WeatherService {
  WeatherService({
    http.Client? client,
    Future<Directory> Function()? directoryProvider,
    WeatherLocation? location,
    Duration timeout = const Duration(seconds: 6),
  })  : _client = client ?? http.Client(),
        _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory,
        _location = location,
        _timeout = timeout;

  static const String endpoint = 'https://api.open-meteo.com/v1/forecast';
  static const double defaultLatitude = -26.2041;
  static const double defaultLongitude = 28.0473;
  static const String cacheFileName = 'cached_weather.json';
  static const String locationFileName = 'weather_location.json';
  static const String tempSuffix = '.tmp';

  final http.Client _client;
  final Future<Directory> Function() _directoryProvider;
  final Duration _timeout;
  WeatherLocation? _location;

  KvStore? _kvStore;

  /// Platform-appropriate persistence for the cache and the selected city.
  ///
  /// On web `path_provider` has no implementation, so the cache and the city
  /// would silently never persist in Safari. Routing both through [KvStore]
  /// keeps them in `localStorage` there and in the atomic file on mobile.
  ///
  /// [QA TEST POINT] Weather context and caching (`cached_weather.json`)
  /// - Pick a city: the caption updates to that name and the choice survives an
  ///   app restart (verified in `weather_location.json`).
  /// - Enable airplane mode, then generate: the card shows the **cached**
  ///   reading and is labelled `(cached)`, never a fabricated live value.
  /// - Clear the cache file: the card falls back to the neutral default and is
  ///   labelled `(default)`.
  /// - A cached reading from a *different* city must not be shown after
  ///   switching; the location id is stored alongside the reading.
  Future<KvStore> kvStore() async =>
      _kvStore ??= await createDefaultKvStore();

  /// The place in use, falling back to the curated default coordinates.
  WeatherLocation get location =>
      _location ??
      const WeatherLocation(
        name: 'Johannesburg',
        latitude: defaultLatitude,
        longitude: defaultLongitude,
      );

  /// Name of the user-selected place, or null when only defaults are in use.
  String? get locationName => _location?.name;

  /// Re-points the service and persists the choice.
  Future<void> setLocation(WeatherLocation value) async {
    _location = value;
    await saveLocation(value);
  }

  /// Neutral fallback used when the device is offline and has no cache.
  static WeatherContext defaultContext({String? locationName}) =>
      WeatherContext(
        temperatureC: 22.0,
        condition: 'warm',
        source: WeatherContext.sourceDefault,
        locationName: locationName,
      );

  /// Maps a temperature to a DLS band.
  static String temperatureBand(double c) {
    if (c > 28) return 'hot';
    if (c >= 20) return 'warm';
    if (c >= 12) return 'mild';
    if (c >= 2) return 'cold';
    return 'freezing';
  }

  /// WMO weather code (0-99) + temperature -> DLS condition.
  ///
  /// Rain and storm families take priority (waterproof beats temperature), then
  /// snow, then the temperature band for clear/cloudy codes.
  static String conditionFor({
    required int wmoCode,
    required double temperatureC,
  }) {
    // Drizzle/rain/showers/thunder -> rain.
    if ((wmoCode >= 51 && wmoCode <= 67) ||
        (wmoCode >= 80 && wmoCode <= 82) ||
        (wmoCode >= 95 && wmoCode <= 99)) {
      return 'rain';
    }
    // Snow -> freezing below 2°C, otherwise cold.
    if ((wmoCode >= 71 && wmoCode <= 77) || (wmoCode >= 85 && wmoCode <= 86)) {
      return temperatureC < 2 ? 'freezing' : 'cold';
    }
    // Clear (0-1) and overcast/fog (2-4) scale with temperature.
    return temperatureBand(temperatureC);
  }

  Future<WeatherContext> current() async {
    try {
      final live = await _fetchLive();
      if (live != null) {
        await _writeCache(live);
        return live;
      }
      if (kDebugMode) {
        debugPrint('[WeatherService] live fetch returned null for '
            '${location.latitude},${location.longitude}');
      }
    } catch (error, stackTrace) {
      // Offline, timed out, or malformed payload: fall through.
      if (kDebugMode) {
        debugPrint('[WeatherService] live fetch failed: $error');
        debugPrint(stackTrace.toString());
      }
    }
    // A cached reading is only reused for the same city it was taken for, so
    // switching city never shows another place's weather.
    final cached = await readCache();
    if (cached != null && _sameCity(cached.locationName, locationName)) {
      return cached;
    }
    return defaultContext(locationName: locationName);
  }

  /// Null means the curated default city, so a missing name matches it.
  static bool _sameCity(String? a, String? b) =>
      (a ?? WeatherLocation.defaultLocation.name) ==
      (b ?? WeatherLocation.defaultLocation.name);

  Future<WeatherContext?> _fetchLive() async {
    final uri = Uri.parse(
      '$endpoint?latitude=${location.latitude}'
      '&longitude=${location.longitude}&current_weather=true',
    );
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;
    // Older shape is `current_weather`; newer Open-Meteo uses `current`.
    final raw = body['current_weather'] ?? body['current'];
    if (raw is! Map<String, dynamic>) return null;

    final temperature = (raw['temperature'] as num?)?.toDouble();
    if (temperature == null) return null;
    final code = (raw['weathercode'] as num?)?.toInt();

    return WeatherContext(
      temperatureC: temperature,
      condition: conditionFor(wmoCode: code ?? 0, temperatureC: temperature),
      source: WeatherContext.sourceLive,
      wmoCode: code,
      observedAt: DateTime.now().toUtc(),
      locationName: locationName,
    );
  }

  Future<File> _cacheFile() async {
    final dir = await _directoryProvider();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$cacheFileName');
  }

  /// Returns the last cached reading, or null when none is usable.
  Future<WeatherContext?> readCache() async {
    try {
      if (kIsWeb) {
        final raw = await (await kvStore()).read(cacheFileName);
        if (raw == null) return null;
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) return null;
        return WeatherContext.fromJson(decoded);
      }
      final file = await _cacheFile();
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return WeatherContext.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Atomic cache write: temp file then rename, so a crash cannot corrupt it.
  Future<void> _writeCache(WeatherContext context) async {
    try {
      final payload = jsonEncode(context.toJson());
      if (kIsWeb) {
        await (await kvStore()).write(cacheFileName, payload);
        return;
      }
      final target = await _cacheFile();
      final temp = File('${target.path}$tempSuffix');
      await temp.writeAsString(payload, flush: true);
      try {
        await temp.rename(target.path);
      } catch (_) {
        if (await target.exists()) await target.delete();
        await temp.rename(target.path);
      }
    } catch (_) {
      // A cache write failure must never break the weather read.
    }
  }

  // --- Location persistence --------------------------------------------------

  Future<File> _locationFile() async {
    final dir = await _directoryProvider();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$locationFileName');
  }

  /// Restores the previously selected location, if any.
  Future<WeatherLocation?> loadLocation() async {
    try {
      if (kIsWeb) {
        final raw = await (await kvStore()).read(locationFileName);
        if (raw == null) return null;
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) return null;
        final location = WeatherLocation.fromJson(decoded);
        if (location != null) _location = location;
        return location;
      }
      final file = await _locationFile();
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final location = WeatherLocation.fromJson(decoded);
      if (location != null) _location = location;
      return location;
    } catch (_) {
      return null;
    }
  }

  /// Atomically persists the selected location.
  Future<void> saveLocation(WeatherLocation value) async {
    try {
      final payload = jsonEncode(value.toJson());
      if (kIsWeb) {
        await (await kvStore()).write(locationFileName, payload);
        return;
      }
      final target = await _locationFile();
      final temp = File('${target.path}$tempSuffix');
      await temp.writeAsString(payload, flush: true);
      try {
        await temp.rename(target.path);
      } catch (_) {
        if (await target.exists()) await target.delete();
        await temp.rename(target.path);
      }
    } catch (_) {
      // Never fail the caller because the preference could not be stored.
    }
  }
}
