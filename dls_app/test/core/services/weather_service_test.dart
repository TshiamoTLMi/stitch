import 'dart:convert';
import 'dart:io';

import 'package:dls_app/core/services/weather_service.dart';
import 'package:dls_app/models/weather_context.dart';
import 'package:dls_app/models/weather_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

WeatherService serviceWith(http.Client client, Directory dir) => WeatherService(
      client: client,
      directoryProvider: () async => dir,
    );

http.Client _live(double temperature, int code) => MockClient((_) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'current_weather': <String, dynamic>{
            'temperature': temperature,
            'weathercode': code,
          },
        }),
        200,
      );
    });

http.Client get _offline =>
    MockClient((_) async => throw SocketException('offline'));

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dls_weather');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('temperature bands', () {
    test('maps temperatures to DLS bands', () {
      expect(WeatherService.temperatureBand(35), 'hot');
      expect(WeatherService.temperatureBand(28.1), 'hot');
      expect(WeatherService.temperatureBand(24), 'warm');
      expect(WeatherService.temperatureBand(20), 'warm');
      expect(WeatherService.temperatureBand(15), 'mild');
      expect(WeatherService.temperatureBand(12), 'mild');
      expect(WeatherService.temperatureBand(5), 'cold');
      expect(WeatherService.temperatureBand(2), 'cold');
      expect(WeatherService.temperatureBand(1.9), 'freezing');
      expect(WeatherService.temperatureBand(-10), 'freezing');
    });
  });

  group('WMO code mapping', () {
    test('clear codes 0-1 scale with temperature', () {
      expect(WeatherService.conditionFor(wmoCode: 0, temperatureC: 33), 'hot');
      expect(WeatherService.conditionFor(wmoCode: 1, temperatureC: 24), 'warm');
      expect(WeatherService.conditionFor(wmoCode: 0, temperatureC: 15), 'mild');
      expect(WeatherService.conditionFor(wmoCode: 1, temperatureC: 7), 'cold');
      expect(WeatherService.conditionFor(wmoCode: 0, temperatureC: -3), 'freezing');
    });

    test('cloudy codes 2-3 scale with temperature', () {
      expect(WeatherService.conditionFor(wmoCode: 2, temperatureC: 14), 'mild');
      expect(WeatherService.conditionFor(wmoCode: 3, temperatureC: 6), 'cold');
      expect(WeatherService.conditionFor(wmoCode: 3, temperatureC: 1), 'freezing');
    });

    test('rain 51-67, 80-82 and 95-99 win over temperature', () {
      for (final code in <int>[51, 55, 61, 63, 65, 67, 80, 81, 82, 95, 96, 99]) {
        expect(WeatherService.conditionFor(wmoCode: code, temperatureC: 30),
            'rain',
            reason: 'hot but code $code must be rain');
        expect(WeatherService.conditionFor(wmoCode: code, temperatureC: -5),
            'rain',
            reason: 'freezing but code $code must be rain');
      }
    });

    test('snow 71-77 and 85-86 is freezing below 2C, otherwise cold', () {
      expect(WeatherService.conditionFor(wmoCode: 71, temperatureC: 1), 'freezing');
      expect(WeatherService.conditionFor(wmoCode: 75, temperatureC: 5), 'cold');
      expect(WeatherService.conditionFor(wmoCode: 85, temperatureC: 4), 'cold');
      expect(WeatherService.conditionFor(wmoCode: 86, temperatureC: 9), 'cold');
    });

    test('unknown codes fall back to the temperature band', () {
      expect(WeatherService.conditionFor(wmoCode: 4, temperatureC: 30), 'hot');
      expect(WeatherService.conditionFor(wmoCode: 199, temperatureC: 12), 'mild');
    });
  });

  group('live fetch', () {
    test('maps a live response and caches it', () async {
      final service = serviceWith(_live(30, 0), tempDir);
      final context = await service.current();
      expect(context.temperatureC, 30.0);
      expect(context.condition, 'hot');
      expect(context.isLive, isTrue);
      expect(context.wmoCode, 0);

      final cached = await serviceWith(_offline, tempDir).readCache();
      expect(cached, isNotNull);
      expect(cached!.temperatureC, 30.0);
    });

    test('accepts the newer `current` response shape', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'current': <String, dynamic>{'temperature': 4.0, 'weathercode': 61},
            }),
            200,
          ));
      final context = await serviceWith(client, tempDir).current();
      expect(context.temperatureC, 4.0);
      expect(context.condition, 'rain');
    });

    test('writes the cache atomically, leaving no temp file', () async {
      await serviceWith(_live(20, 3), tempDir).current();
      final target =
          File('${tempDir.path}${Platform.pathSeparator}cached_weather.json');
      expect(target.existsSync(), isTrue);
      expect(File('${target.path}.tmp').existsSync(), isFalse);
    });
  });

  group('offline behaviour', () {
    test('falls back to the cache when the network fails', () async {
      await serviceWith(_live(8, 3), tempDir).current();
      final context = await serviceWith(_offline, tempDir).current();
      expect(context.isCached, isTrue);
      expect(context.temperatureC, 8.0);
    });

    test('falls back to the default when offline and uncached', () async {
      final context = await serviceWith(_offline, tempDir).current();
      expect(context.isDefault, isTrue);
      expect(context.temperatureC, 22.0);
      expect(context.condition, 'warm');
    });

    test('falls back on a non-200 response', () async {
      final client = MockClient((_) async => http.Response('nope', 503));
      final context = await serviceWith(client, tempDir).current();
      expect(context.isDefault, isTrue);
    });

    test('ignores a corrupt cache file instead of throwing', () async {
      File('${tempDir.path}${Platform.pathSeparator}cached_weather.json')
          .writeAsStringSync('{not json');
      final context = await serviceWith(_offline, tempDir).current();
      expect(context.isDefault, isTrue);
    });
  });

  group('weather context', () {
    test('exposes a human label', () {
      const context = WeatherContext(
        temperatureC: 24.4,
        condition: 'rain',
        source: WeatherContext.sourceLive,
      );
      expect(context.label, '24°C Rain');
      expect(context.isRain, isTrue);
    });

    test('flags stale readings', () {
      final fresh = WeatherContext(
        temperatureC: 20,
        condition: 'mild',
        source: WeatherContext.sourceLive,
        observedAt: DateTime.now().toUtc(),
      );
      expect(fresh.isStale(), isFalse);

      final old = WeatherContext(
        temperatureC: 20,
        condition: 'mild',
        source: WeatherContext.sourceCache,
        observedAt: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
      );
      expect(old.isStale(), isTrue);

      const untimed = WeatherContext(
        temperatureC: 22,
        condition: 'warm',
        source: WeatherContext.sourceDefault,
      );
      expect(untimed.isStale(), isTrue);
    });
  });

  group('location configuration', () {
    test('presets are well formed and have a default', () {
      expect(WeatherLocation.presets, isNotEmpty);
      for (final option in WeatherLocation.presets) {
        expect(option.name, isNotEmpty);
        expect(option.latitude, inInclusiveRange(-90.0, 90.0));
        expect(option.longitude, inInclusiveRange(-180.0, 180.0));
      }
      expect(WeatherLocation.defaultLocation, WeatherLocation.presets.first);
    });

    test('falls back to default coordinates when no place is chosen', () {
      final service = serviceWith(_offline, tempDir);
      expect(service.locationName, isNull);
      expect(service.location.latitude, WeatherService.defaultLatitude);
      expect(service.location.longitude, WeatherService.defaultLongitude);
    });

    test('saveLocation persists and loadLocation restores it', () async {
      const capeTown = WeatherLocation(
        name: 'Cape Town',
        latitude: -33.9249,
        longitude: 18.4241,
      );
      await serviceWith(_offline, tempDir).saveLocation(capeTown);

      final file =
          File('${tempDir.path}${Platform.pathSeparator}weather_location.json');
      expect(file.existsSync(), isTrue);
      expect(File('${file.path}.tmp').existsSync(), isFalse);

      final restored = await serviceWith(_offline, tempDir).loadLocation();
      expect(restored, capeTown);
    });

    test('loadLocation returns null when nothing was saved', () async {
      expect(await serviceWith(_offline, tempDir).loadLocation(), isNull);
    });

    test('ignores a corrupt location file', () async {
      File('${tempDir.path}${Platform.pathSeparator}weather_location.json')
          .writeAsStringSync('{not json');
      expect(await serviceWith(_offline, tempDir).loadLocation(), isNull);
    });

    test('setLocation repoints the request and tags the reading', () async {
      late String requested;
      final client = MockClient((request) async {
        requested = request.url.toString();
        return http.Response(
          jsonEncode(<String, dynamic>{
            'current_weather': <String, dynamic>{
              'temperature': 19.0,
              'weathercode': 0,
            },
          }),
          200,
        );
      });
      final service = serviceWith(client, tempDir);
      const durban = WeatherLocation(
        name: 'Durban',
        latitude: -29.8587,
        longitude: 31.0218,
      );
      await service.setLocation(durban);

      final context = await service.current();
      expect(requested, contains('-29.8587'));
      expect(requested, contains('31.0218'));
      expect(context.locationName, 'Durban');
      expect(context.locationLabel, contains('Durban'));
      expect(context.temperatureC, 19.0);
    });

    test('offline default still names the selected location', () async {
      final service = serviceWith(_offline, tempDir);
      await service.setLocation(
        const WeatherLocation(name: 'Pretoria', latitude: -25.7479, longitude: 28.2293),
      );
      final context = await service.current();
      expect(context.isDefault, isTrue);
      expect(context.locationName, 'Pretoria');
    });
  });
}
