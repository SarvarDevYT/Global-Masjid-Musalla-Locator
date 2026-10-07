import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double lat;
  final double lng;
  final bool isDefaultFallback;
  final String? errorMessage;

  LocationResult({
    required this.lat,
    required this.lng,
    this.isDefaultFallback = false,
    this.errorMessage,
  });
}

class LocationService {
  // Default fallback (Hazrati Imom / Tashkent)
  static const double defaultLat = 41.3381;
  static const double defaultLng = 69.2415;

  static Future<LocationResult> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          lat: defaultLat,
          lng: defaultLng,
          isDefaultFallback: true,
          errorMessage: 'Location services are disabled.',
        );
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            lat: defaultLat,
            lng: defaultLng,
            isDefaultFallback: true,
            errorMessage: 'Location permissions are denied.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          lat: defaultLat,
          lng: defaultLng,
          isDefaultFallback: true,
          errorMessage: 'Location permissions are permanently denied.',
        );
      }

      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
        position = current;
      } catch (_) {
        // If high accuracy times out, keep lastKnownPosition
      }

      if (position == null) {
        return LocationResult(
          lat: defaultLat,
          lng: defaultLng,
          isDefaultFallback: true,
          errorMessage: 'Could not obtain GPS position.',
        );
      }

      return LocationResult(
        lat: position.latitude,
        lng: position.longitude,
        isDefaultFallback: false,
      );
    } catch (e) {
      return LocationResult(
        lat: defaultLat,
        lng: defaultLng,
        isDefaultFallback: true,
        errorMessage: e.toString(),
      );
    }
  }
}
