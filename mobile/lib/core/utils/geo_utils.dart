import 'dart:math' as math;
import '../constants/api_constants.dart';

class GeoUtils {
  /// Calculate spherical distance between two coordinates in meters
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // in meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Format distance according to spec: <1km in meters (e.g. "350 m"), otherwise "2.4 km"
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final double km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Calculate the Qibla angle (direction to Mecca) in degrees [0, 360)
  static double calculateQiblaBearing(double userLat, double userLng) {
    final double phiK = _toRadians(ApiConstants.meccaLat);
    final double lambdaK = _toRadians(ApiConstants.meccaLng);
    final double phi = _toRadians(userLat);
    final double lambda = _toRadians(userLng);

    final double psi = math.atan2(
      math.sin(lambdaK - lambda),
      math.cos(phi) * math.tan(phiK) - math.sin(phi) * math.cos(lambdaK - lambda),
    );

    double degrees = _toDegrees(psi);
    return (degrees + 360) % 360;
  }

  static double _toRadians(double degree) => degree * math.pi / 180.0;
  static double _toDegrees(double radian) => radian * 180.0 / math.pi;
}
