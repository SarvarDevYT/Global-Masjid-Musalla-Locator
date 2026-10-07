class ApiConstants {
  // Local backend server (Use 10.0.2.2 for Android Emulator, localhost for iOS/Web/Desktop)
  static const String defaultBaseUrl = 'http://127.0.0.1:3000/api/v1';
  
  // Public Overpass API fallback for instant worldwide operation without backend
  static const String overpassUrl = 'https://overpass-api.de/api/interpreter';

  // Mecca Coordinates for Qibla calculation
  static const double meccaLat = 21.4225;
  static const double meccaLng = 39.8262;
}
