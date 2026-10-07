import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mosque_model.dart';
import '../../core/constants/api_constants.dart';

class ApiService {
  final http.Client _client = http.Client();

  Future<List<MosqueModel>> fetchNearbyMosques({
    required double lat,
    required double lng,
    double radiusMeters = 15000,
    String? type,
    String? query,
    bool? hasWuduWomen,
    bool? hasWomenPrayerArea,
    bool? hasJuma,
    bool? hasWheelchairAccess,
    bool? hasParking,
  }) async {
    final queryParams = {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radiusMeters.round().toString(),
      if (type != null) 'type': type,
      if (query != null && query.isNotEmpty) 'q': query,
      if (hasWuduWomen == true) 'has_wudu_women': 'true',
      if (hasWomenPrayerArea == true) 'has_women_prayer_area': 'true',
      if (hasJuma == true) 'has_juma': 'true',
      if (hasWheelchairAccess == true) 'has_wheelchair_access': 'true',
      if (hasParking == true) 'has_parking': 'true',
    };

    final uri = Uri.parse('${ApiConstants.defaultBaseUrl}/mosques/nearby').replace(queryParameters: queryParams);

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final list = (data['data'] as List)
              .map((item) => MosqueModel.fromJson(item))
              .toList();
          if (list.isNotEmpty) return list;
        }
      }
    } catch (_) {
      // Backend not reached or offline: fallback to direct Overpass query
    }

    // Direct OpenStreetMap Overpass Fallback for instant worldwide operation
    return await _fetchFromOverpass(lat: lat, lng: lng, radiusMeters: radiusMeters);
  }

  Future<List<MosqueModel>> _fetchFromOverpass({
    required double lat,
    required double lng,
    required double radiusMeters,
  }) async {
    final safeRadius = radiusMeters.clamp(500, 25000).round();
    final overpassQuery = '''
      [out:json][timeout:15];
      (
        node["amenity"="place_of_worship"]["religion"="muslim"](around:$safeRadius,$lat,$lng);
        way["amenity"="place_of_worship"]["religion"="muslim"](around:$safeRadius,$lat,$lng);
      );
      out center tags 40;
    ''';

    try {
      final response = await _client.post(
        Uri.parse(ApiConstants.overpassUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'MasjidLocator/1.0 (com.masjidlocator.masjid_locator)',
        },
        body: 'data=${Uri.encodeComponent(overpassQuery)}',
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['elements'] as List? ?? [];
        return elements.map((el) {
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final itemLat = (el['lat'] ?? el['center']?['lat'] as num?)?.toDouble() ?? lat;
          final itemLng = (el['lon'] ?? el['center']?['lon'] as num?)?.toDouble() ?? lng;
          final name = tags['name'] ?? tags['name:en'] ?? tags['name:uz'] ?? tags['name:ru'] ?? 'Masjid / Musalla';
          final isMusalla = tags['building'] == 'room' ||
              (tags['name']?.toString().toLowerCase().contains('namozxona') ?? false) ||
              (tags['name']?.toString().toLowerCase().contains('musalla') ?? false);

          final hasWomen = tags['female'] == 'yes' || tags['women'] == 'yes';

          return MosqueModel(
            id: el['id'].toString(),
            osmId: el['id'] as int?,
            name: name,
            address: tags['addr:street'] ?? tags['addr:city'] ?? '',
            city: tags['addr:city'],
            country: tags['addr:country'],
            type: isMusalla ? 'musalla' : 'masjid',
            lat: itemLat,
            lng: itemLng,
            hasWuduMen: true,
            hasWuduWomen: hasWomen,
            hasWomenPrayerArea: hasWomen,
            hasJuma: !isMusalla,
            hasWheelchairAccess: tags['wheelchair'] == 'yes',
            hasParking: tags['parking'] == 'yes',
            status: 'approved',
            verifiedCount: 5,
          );
        }).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<bool> submitMosque(Map<String, dynamic> mosqueData) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.defaultBaseUrl}/mosques/contribute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(mosqueData),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> submitReport(String mosqueId, String reason, String details) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.defaultBaseUrl}/mosques/$mosqueId/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reason': reason, 'details': details}),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
