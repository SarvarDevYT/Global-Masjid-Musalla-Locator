class ApiConstants {
  // Live cloud backend on Vercel with Neon PostgreSQL + PostGIS
  static const String defaultBaseUrl = 'https://global-masjid-musalla-locator.vercel.app/api/v1';
  
  // Public Overpass API fallback for instant worldwide operation without backend
  static const String overpassUrl = 'https://overpass-api.de/api/interpreter';

  // Mecca Coordinates for Qibla calculation
  static const double meccaLat = 21.4225;
  static const double meccaLng = 39.8262;
}
