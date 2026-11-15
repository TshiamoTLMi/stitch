import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/weather_location.dart';

/// Resolves the device's approximate current location into a
/// [WeatherLocation], for the "Use My Location" weather option.
///
/// This sits entirely on top of the existing [WeatherLocation]/`WeatherService`
/// pair - it never touches their caching or fallback logic, it only produces
/// one more [WeatherLocation] value the same way a manually-picked preset
/// city would. Every failure path (no permission, service disabled, a
/// platform exception, a geocoder that cannot resolve a name) returns null
/// rather than throwing, so the caller always has a graceful path back to
/// the manual city picker.
///
/// [QA TEST POINT] Automatic location
/// - Granting permission shows the real city name and live weather for it.
/// - Denying permission falls back to the manual preset list with no crash.
/// - "Don't ask again" / deniedForever surfaces an "open settings" path
///   rather than silently retrying forever.
class LocationService {
  const LocationService();

  /// Detects the current position and reverse-geocodes it to a city name.
  /// Returns null on any failure - callers should fall back to the manual
  /// city picker in that case.
  Future<WeatherLocation?> detectCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (kDebugMode) debugPrint('[LocationService] location service disabled');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          debugPrint('[LocationService] permission not granted: $permission');
        }
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final name = await _reverseGeocode(position.latitude, position.longitude);
      if (kDebugMode) {
        debugPrint('[LocationService] detected '
            '${position.latitude},${position.longitude} -> ${name ?? '(no name)'}');
      }
      return WeatherLocation(
        name: name ?? 'Current Location',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[LocationService] detectCurrentLocation failed: $error');
        debugPrint(stackTrace.toString());
      }
      return null;
    }
  }

  /// True when permission was permanently denied, i.e. the only way forward
  /// is the OS settings screen rather than asking again in-app.
  Future<bool> isPermanentlyDenied() async {
    try {
      return await Geolocator.checkPermission() ==
          LocationPermission.deniedForever;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openSettings() => Geolocator.openAppSettings();

  Future<String?> _reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks =
          await Geocoding().placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      final name = place.locality?.trim().isNotEmpty == true
          ? place.locality!.trim()
          : place.subAdministrativeArea?.trim();
      return (name == null || name.isEmpty) ? null : name;
    } catch (error) {
      if (kDebugMode) debugPrint('[LocationService] reverse geocode failed: $error');
      return null;
    }
  }
}
