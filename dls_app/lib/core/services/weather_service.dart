import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/weather_context.dart';

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
    double? latitude,
    double? longitude,
    Duration timeout = const Duration(seconds: 6),
  })  : _client = client ?? http.Client(),
        _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory,
        latitude = latitude ?? defaultLatitude,
        longitude = longitude ?? defaultLongitude,
        _timeout = timeout;

  static const String endpoint = 'https://api.open-meteo.com/v1/forecast';
  static const double defaultLatitude = -26.2041;
  static const double defaultLongitude = 28.0473;
  static const String cacheFileName = 'cached_weather.json';
  static const String tempSuffix = '.tmp';

  final http.Client _client;
  final Future<Directory> Function() _directoryProvider;
  final double latitude;
  final double longitude;
  final Duration _timeout;

  /// Neutral fallback used when the device is offline and has no cache.
  static WeatherContext defaultContext() => const WeatherContext(
        temperatureC: 22.0,
        condition: 'warm',
        source: WeatherContext.sourceDefault,
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
    } catch (_) {
      // Offline, timed out, or malformed payload: fall through.
    }
    return await readCache() ?? defaultContext();
  }

  Future<WeatherContext?> _fetchLive() async {
    final uri = Uri.parse(
      '$endpoint?latitude=$latitude&longitude=$longitude&current_weather=true',
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
      final target = await _cacheFile();
      final temp = File('${target.path}$tempSuffix');
      await temp.writeAsString(jsonEncode(context.toJson()), flush: true);
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
}
