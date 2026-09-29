/// A selectable weather location.
///
/// Coordinates are passed straight to Open-Meteo. `geolocator` is deliberately
/// not a dependency, so the location is chosen manually and persisted; a device
/// location can be wired in later by resolving it to a [WeatherLocation].
class WeatherLocation {
  const WeatherLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  /// A short curated set of South African cities.
  static const List<WeatherLocation> presets = <WeatherLocation>[
    WeatherLocation(name: 'Johannesburg', latitude: -26.2041, longitude: 28.0473),
    WeatherLocation(name: 'Cape Town', latitude: -33.9249, longitude: 18.4241),
    WeatherLocation(name: 'Durban', latitude: -29.8587, longitude: 31.0218),
    WeatherLocation(name: 'Pretoria', latitude: -25.7479, longitude: 28.2293),
    WeatherLocation(name: 'Bloemfontein', latitude: -29.1042, longitude: 26.2007),
    WeatherLocation(name: 'Gqeberha', latitude: -33.9608, longitude: 25.6022),
  ];

  static WeatherLocation get defaultLocation => presets.first;

  static WeatherLocation? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final lat = (json['latitude'] as num?)?.toDouble();
    final lon = (json['longitude'] as num?)?.toDouble();
    if (name is! String || name.isEmpty || lat == null || lon == null) {
      return null;
    }
    return WeatherLocation(name: name, latitude: lat, longitude: lon);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  @override
  bool operator ==(Object other) =>
      other is WeatherLocation &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, latitude, longitude);

  @override
  String toString() => name;
}
