import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mosque_model.dart';
import '../services/api_service.dart';
import '../../core/utils/geo_utils.dart';

class MosqueRepository {
  final ApiService _apiService;
  static const String _cacheKey = 'cached_mosques_v1';

  MosqueRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

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

    // 1. Try fetching from network (Live Backend with 2300+ Uzbekistan Mosques or Overpass API)
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

    // 2. If network returned nothing (or offline), load from cache
    if (results.isEmpty) {
      final cached = await _loadFromCache();
      results = cached;
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

  /// Skanerlash va yangi topilgan masjidlarni bazaga kiritish
  Future<ScanResult> scanAndSyncArea({
    required double userLat,
    required double userLng,
    double radiusMeters = 25000,
  }) async {
    final result = await _apiService.scanAndSyncNearby(
      lat: userLat,
      lng: userLng,
      radiusMeters: radiusMeters,
    );

    if (result.mosques.isNotEmpty) {
      await _saveToCache(result.mosques);
    }

    final listWithDistance = result.mosques.map((m) {
      final dist = GeoUtils.calculateDistance(userLat, userLng, m.lat, m.lng);
      return m.copyWith(distanceMeters: dist);
    }).toList();

    listWithDistance.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));

    return ScanResult(
      mosques: listWithDistance,
      newlyAddedCount: result.newlyAddedCount,
    );
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
