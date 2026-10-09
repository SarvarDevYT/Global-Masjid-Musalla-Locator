import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mosque_model.dart';
import '../services/api_service.dart';
import '../../core/utils/geo_utils.dart';

class MosqueRepository {
  final ApiService _apiService;
  static const String _cacheKey = 'cached_mosques_v1';
  static List<MosqueModel>? _memoryAllMosques;

  MosqueRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  /// Butun O'zbekistondagi barcha 2300+ masjidlarni olish (Xarita va qidiruv uchun)
  Future<List<MosqueModel>> getAllMosques({
    double? userLat,
    double? userLng,
    String? type,
    String? query,
    bool? hasWuduWomen,
    bool? hasWomenPrayerArea,
    bool? hasJuma,
    bool? hasWheelchairAccess,
    bool? hasParking,
  }) async {
    // 1. Agar xotirada bo'lmasa, dastur paketidagi (assets) 2310 ta masjiddan bir lahzada yuklash
    if (_memoryAllMosques == null || _memoryAllMosques!.isEmpty) {
      _memoryAllMosques = await _loadBundledMosques();
    }

    // 2. Orqa fonda serverdan yangi kiritilganlarini yangilash
    _syncAllMosquesFromServer();

    List<MosqueModel> list = List.from(_memoryAllMosques ?? []);

    // 3. Agar foydalanuvchi joylashuvi bo'lsa, masofani hisoblash
    if (userLat != null && userLng != null) {
      list = list.map((m) {
        final dist = GeoUtils.calculateDistance(userLat, userLng, m.lat, m.lng);
        return m.copyWith(distanceMeters: dist);
      }).toList();
    }

    // 4. Filtrlash (turi, tahoratxona, juma, qidiruv so'zi)
    final filtered = list.where((m) {
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
            m.address.toLowerCase().contains(q) ||
            (m.city?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      return true;
    }).toList();

    if (userLat != null && userLng != null) {
      filtered.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
    }

    return filtered;
  }

  Future<List<MosqueModel>> _loadBundledMosques() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/uzbekistan_mosques.json');
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is List) {
        final items = decoded
            .map((item) => MosqueModel.fromJson(item as Map<String, dynamic>))
            .toList();
        if (items.isNotEmpty) return items;
      }
    } catch (_) {}
    return await _loadFromCache();
  }

  void _syncAllMosquesFromServer() {
    _apiService.fetchAllMosques().then((remoteList) {
      if (remoteList.isNotEmpty) {
        _memoryAllMosques = remoteList;
        _saveToCache(remoteList);
      }
    }).catchError((_) {});
  }

  Future<List<MosqueModel>> getNearbyMosques({
    required double userLat,
    required double userLng,
    double radiusMeters = 25000,
    String? type,
    String? query,
    bool? hasWuduWomen,
    bool? hasWomenPrayerArea,
    bool? hasJuma,
    bool? hasWheelchairAccess,
    bool? hasParking,
  }) async {
    List<MosqueModel> results = [];

    // 1. Try fetching from network (Live Backend with 2300+ Uzbekistan Mosques)
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
        await _saveToCache(results);
      }
    } catch (_) {
      // Network failed
    }

    // 2. If network returned nothing (or offline), load from full Uzbekistan dataset
    if (results.isEmpty) {
      return await getAllMosques(
        userLat: userLat,
        userLng: userLng,
        type: type,
        query: query,
        hasWuduWomen: hasWuduWomen,
        hasWomenPrayerArea: hasWomenPrayerArea,
        hasJuma: hasJuma,
        hasWheelchairAccess: hasWheelchairAccess,
        hasParking: hasParking,
      );
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
