import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mosque_model.dart';
import '../services/api_service.dart';
import '../../core/utils/geo_utils.dart';

class MosqueRepository {
  final ApiService _apiService;
  static const String _cacheKey = 'cached_mosques_v1';

  MosqueRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  // Built-in offline seeds
  static final List<MosqueModel> _defaultSeeds = [
    const MosqueModel(
      id: 'seed-1',
      name: 'Hazrati Imom (Hastimom) Masjidi',
      altName: 'Hazrat Imam Mosque',
      address: 'Qorasaroy ko\'chasi, Olmazor tumani, Toshkent',
      city: 'Toshkent',
      country: 'O\'zbekiston',
      type: 'masjid',
      lat: 41.3381,
      lng: 69.2415,
      hasWuduMen: true,
      hasWuduWomen: true,
      hasWomenPrayerArea: true,
      hasJuma: true,
      hasWheelchairAccess: true,
      hasParking: true,
      photoUrl: 'https://images.unsplash.com/photo-1590076212455-83e9ea43a18e?w=800',
      status: 'approved',
      verifiedCount: 48,
    ),
    const MosqueModel(
      id: 'seed-2',
      name: 'Minor Masjidi',
      altName: 'Minor Mosque',
      address: 'Kichik halqa yo\'li, Yunusobod tumani, Toshkent',
      city: 'Toshkent',
      country: 'O\'zbekiston',
      type: 'masjid',
      lat: 41.3283,
      lng: 69.2817,
      hasWuduMen: true,
      hasWuduWomen: true,
      hasWomenPrayerArea: true,
      hasJuma: true,
      hasWheelchairAccess: true,
      hasParking: true,
      photoUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=800',
      status: 'approved',
      verifiedCount: 52,
    ),
    const MosqueModel(
      id: 'seed-3',
      name: 'Shayx Zayniddin (Ko\'kcha) Masjidi',
      altName: 'Kukcha Mosque',
      address: 'Ko\'kcha Darvoza ko\'chasi, Shayxontohur tumani, Toshkent',
      city: 'Toshkent',
      country: 'O\'zbekiston',
      type: 'masjid',
      lat: 41.3214,
      lng: 69.2141,
      hasWuduMen: true,
      hasWuduWomen: true,
      hasWomenPrayerArea: true,
      hasJuma: true,
      hasWheelchairAccess: true,
      hasParking: true,
      photoUrl: 'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?w=800',
      status: 'approved',
      verifiedCount: 40,
    ),
    const MosqueModel(
      id: 'seed-4',
      name: 'Tashkent City Mall Musalla',
      altName: 'Shopping Center Prayer Room',
      address: 'Botir Zokirov ko\'chasi, Tashkent City, Toshkent',
      city: 'Toshkent',
      country: 'O\'zbekiston',
      type: 'musalla',
      lat: 41.3115,
      lng: 69.2530,
      hasWuduMen: true,
      hasWuduWomen: true,
      hasWomenPrayerArea: true,
      hasJuma: false,
      hasWheelchairAccess: true,
      hasParking: true,
      photoUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800',
      status: 'approved',
      verifiedCount: 22,
    ),
    const MosqueModel(
      id: 'seed-5',
      name: 'Al-Masjid an-Nabawi',
      altName: 'Prophet\'s Mosque',
      address: 'Al Haram, Medina 42311, Saudi Arabia',
      city: 'Medina',
      country: 'Saudi Arabia',
      type: 'masjid',
      lat: 24.4672,
      lng: 39.6111,
      hasWuduMen: true,
      hasWuduWomen: true,
      hasWomenPrayerArea: true,
      hasJuma: true,
      hasWheelchairAccess: true,
      hasParking: true,
      status: 'approved',
      verifiedCount: 500,
    ),
    const MosqueModel(
      id: 'seed-6',
      name: 'Al-Masjid al-Haram',
      altName: 'The Sacred Mosque',
      address: 'Al Haram, Mecca 24231, Saudi Arabia',
      city: 'Mecca',
      country: 'Saudi Arabia',
      type: 'masjid',
      lat: 21.4225,
      lng: 39.8262,
      hasWuduMen: true,
      hasWuduWomen: true,
      hasWomenPrayerArea: true,
      hasJuma: true,
      hasWheelchairAccess: true,
      hasParking: true,
      status: 'approved',
      verifiedCount: 1000,
    ),
  ];

  Future<List<MosqueModel>> getNearbyMosques({
    required double userLat,
    required double userLng,
    double radiusMeters = 20000,
    String? type,
    String? query,
    bool? hasWuduWomen,
    bool? hasWomenPrayerArea,
    bool? hasJuma,
    bool? hasWheelchairAccess,
    bool? hasParking,
  }) async {
    List<MosqueModel> results = [];

    // 1. Try fetching from network (Backend or Overpass API)
    try {
      results = await _apiService.fetchNearbyMosques(
        lat: userLat,
        lng: userLng,
        radiusMeters: radiusMeters,
        type: type,
        query: query,
        hasWuduWomen: hasWuduWomen,
        hasWomenPrayerArea: hasWomenPrayerArea,
        hasJuma: hasJuma,
        hasWheelchairAccess: hasWheelchairAccess,
        hasParking: hasParking,
      );

      if (results.isNotEmpty) {
        // Save to offline cache
        await _saveToCache(results);
      }
    } catch (_) {
      // Network failed
    }

    // 2. If network returned nothing (or offline), load from cache & defaults
    if (results.isEmpty) {
      final cached = await _loadFromCache();
      results = cached.isNotEmpty ? cached : _defaultSeeds;
    }

    // 3. Compute distance from current user coordinates and sort ascending
    final listWithDistance = results.map((m) {
      final dist = GeoUtils.calculateDistance(userLat, userLng, m.lat, m.lng);
      return m.copyWith(distanceMeters: dist);
    }).toList();

    // 4. Apply client-side filters if needed
    final filtered = listWithDistance.where((m) {
      if (type != null && type != 'all' && m.type.toLowerCase() != type.toLowerCase()) {
        return false;
      }
      if (hasWuduWomen == true && !m.hasWuduWomen) return false;
      if (hasWomenPrayerArea == true && !m.hasWomenPrayerArea) return false;
      if (hasJuma == true && !m.hasJuma) return false;
      if (hasWheelchairAccess == true && !m.hasWheelchairAccess) return false;
      if (hasParking == true && !m.hasParking) return false;
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        final match = m.name.toLowerCase().contains(q) ||
            (m.altName?.toLowerCase().contains(q) ?? false) ||
            m.address.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    // Ascending sort by distance
    filtered.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
    return filtered;
  }

  Future<void> _saveToCache(List<MosqueModel> mosques) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = mosques.map((m) => m.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<List<MosqueModel>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey);
      if (str != null) {
        final decoded = jsonDecode(str) as List;
        return decoded.map((item) => MosqueModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> contributeMosque(Map<String, dynamic> data) async {
    return await _apiService.submitMosque(data);
  }

  Future<bool> reportIssue(String mosqueId, String reason, String details) async {
    return await _apiService.submitReport(mosqueId, reason, details);
  }
}
