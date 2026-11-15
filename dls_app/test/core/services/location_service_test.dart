import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'package:dls_app/core/services/location_service.dart';

/// A controllable fake replacing the real platform channel, following the
/// pattern geolocator's own docs recommend for unit testing.
class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  _FakeGeolocatorPlatform({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.position,
    this.throwOnPosition = false,
  });

  bool serviceEnabled;
  LocationPermission permission;
  Position? position;
  bool throwOnPosition;
  bool openedSettings = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (throwOnPosition) throw Exception('platform failure');
    return position!;
  }

  @override
  Future<bool> openAppSettings() async {
    openedSettings = true;
    return true;
  }
}

class _FakeGeocoding extends Geocoding {
  _FakeGeocoding(super.params, {this.placemarks, this.throwOnLookup = false})
      : super.implementation();

  List<Placemark>? placemarks;
  bool throwOnLookup;

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    dynamic locale,
  }) async {
    if (throwOnLookup) throw Exception('geocoder failure');
    return placemarks ?? const <Placemark>[];
  }
}

class _FakeGeocodingPlatformFactory extends GeocodingPlatformFactory {
  _FakeGeocodingPlatformFactory({this.placemarks, this.throwOnLookup = false});

  List<Placemark>? placemarks;
  bool throwOnLookup;

  @override
  Geocoding createGeocoding(GeocodingCreationParams params) =>
      _FakeGeocoding(params, placemarks: placemarks, throwOnLookup: throwOnLookup);
}

Position _position({double lat = -26.1, double lon = 28.0}) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime(2026, 1, 1),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  const service = LocationService();

  test('returns null when the location service is disabled', () async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(serviceEnabled: false);
    GeocodingPlatformFactory.instance = _FakeGeocodingPlatformFactory();

    expect(await service.detectCurrentLocation(), isNull);
  });

  test('returns null when permission is denied', () async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      permission: LocationPermission.denied,
    );
    GeocodingPlatformFactory.instance = _FakeGeocodingPlatformFactory();

    expect(await service.detectCurrentLocation(), isNull);
  });

  test('returns null when permission is permanently denied, and reports that',
      () async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      permission: LocationPermission.deniedForever,
    );
    GeocodingPlatformFactory.instance = _FakeGeocodingPlatformFactory();

    expect(await service.detectCurrentLocation(), isNull);
    expect(await service.isPermanentlyDenied(), isTrue);
  });

  test('resolves coordinates to the reverse-geocoded city name', () async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      position: _position(lat: -33.9249, lon: 18.4241),
    );
    GeocodingPlatformFactory.instance = _FakeGeocodingPlatformFactory(
      placemarks: const [Placemark(locality: 'Cape Town')],
    );

    final location = await service.detectCurrentLocation();

    expect(location, isNotNull);
    expect(location!.name, 'Cape Town');
    expect(location.latitude, -33.9249);
    expect(location.longitude, 18.4241);
  });

  test('falls back to coordinates with a generic name when reverse-geocoding '
      'fails - a geocoder error never blocks weather from working', () async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(position: _position());
    GeocodingPlatformFactory.instance =
        _FakeGeocodingPlatformFactory(throwOnLookup: true);

    final location = await service.detectCurrentLocation();

    expect(location, isNotNull);
    expect(location!.name, 'Current Location');
  });

  test('falls back to coordinates with a generic name when the geocoder '
      'returns no placemarks', () async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(position: _position());
    GeocodingPlatformFactory.instance =
        _FakeGeocodingPlatformFactory(placemarks: const []);

    final location = await service.detectCurrentLocation();

    expect(location, isNotNull);
    expect(location!.name, 'Current Location');
  });

  test('returns null, not a thrown exception, when the platform call fails',
      () async {
    GeolocatorPlatform.instance =
        _FakeGeolocatorPlatform(throwOnPosition: true);
    GeocodingPlatformFactory.instance = _FakeGeocodingPlatformFactory();

    expect(await service.detectCurrentLocation(), isNull);
  });

  test('openSettings delegates to the platform', () async {
    final fake = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fake;
    GeocodingPlatformFactory.instance = _FakeGeocodingPlatformFactory();

    await service.openSettings();

    expect(fake.openedSettings, isTrue);
  });
}
