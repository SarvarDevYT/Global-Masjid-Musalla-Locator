class MosqueModel {
  final String id;
  final int? osmId;
  final String name;
  final String? altName;
  final String address;
  final String? city;
  final String? country;
  final String type; // 'masjid' or 'musalla'
  final double lat;
  final double lng;
  final bool hasWuduMen;
  final bool hasWuduWomen;
  final bool hasWomenPrayerArea;
  final bool hasJuma;
  final bool hasWheelchairAccess;
  final bool hasParking;
  final String? photoUrl;
  final String status;
  final int verifiedCount;
  final double? distanceMeters;

  const MosqueModel({
    required this.id,
    this.osmId,
    required this.name,
    this.altName,
    required this.address,
    this.city,
    this.country,
    this.type = 'masjid',
    required this.lat,
    required this.lng,
    this.hasWuduMen = true,
    this.hasWuduWomen = false,
    this.hasWomenPrayerArea = false,
    this.hasJuma = true,
    this.hasWheelchairAccess = false,
    this.hasParking = false,
    this.photoUrl,
    this.status = 'approved',
    this.verifiedCount = 0,
    this.distanceMeters,
  });

  bool get isMasjid => type.toLowerCase() == 'masjid';
  bool get isMusalla => type.toLowerCase() == 'musalla';

  String get formattedDistance {
    if (distanceMeters == null) return 'Yaqin';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()} m';
    }
    return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
  }

  MosqueModel copyWith({
    String? id,
    int? osmId,
    String? name,
    String? altName,
    String? address,
    String? city,
    String? country,
    String? type,
    double? lat,
    double? lng,
    bool? hasWuduMen,
    bool? hasWuduWomen,
    bool? hasWomenPrayerArea,
    bool? hasJuma,
    bool? hasWheelchairAccess,
    bool? hasParking,
    String? photoUrl,
    String? status,
    int? verifiedCount,
    double? distanceMeters,
  }) {
    return MosqueModel(
      id: id ?? this.id,
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      altName: altName ?? this.altName,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      hasWuduMen: hasWuduMen ?? this.hasWuduMen,
      hasWuduWomen: hasWuduWomen ?? this.hasWuduWomen,
      hasWomenPrayerArea: hasWomenPrayerArea ?? this.hasWomenPrayerArea,
      hasJuma: hasJuma ?? this.hasJuma,
      hasWheelchairAccess: hasWheelchairAccess ?? this.hasWheelchairAccess,
      hasParking: hasParking ?? this.hasParking,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      verifiedCount: verifiedCount ?? this.verifiedCount,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  factory MosqueModel.fromJson(Map<String, dynamic> json) {
    return MosqueModel(
      id: json['id']?.toString() ?? '',
      osmId: json['osm_id'] != null ? int.tryParse(json['osm_id'].toString()) : null,
      name: json['name']?.toString() ?? 'Masjid',
      altName: json['alt_name']?.toString(),
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString(),
      country: json['country']?.toString(),
      type: json['type']?.toString() ?? 'masjid',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      hasWuduMen: json['has_wudu_men'] == true,
      hasWuduWomen: json['has_wudu_women'] == true,
      hasWomenPrayerArea: json['has_women_prayer_area'] == true,
      hasJuma: json['has_juma'] == true,
      hasWheelchairAccess: json['has_wheelchair_access'] == true,
      hasParking: json['has_parking'] == true,
      photoUrl: json['photo_url']?.toString(),
      status: json['status']?.toString() ?? 'approved',
      verifiedCount: (json['verified_count'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'osm_id': osmId,
      'name': name,
      'alt_name': altName,
      'address': address,
      'city': city,
      'country': country,
      'type': type,
      'lat': lat,
      'lng': lng,
      'has_wudu_men': hasWuduMen,
      'has_wudu_women': hasWuduWomen,
      'has_women_prayer_area': hasWomenPrayerArea,
      'has_juma': hasJuma,
      'has_wheelchair_access': hasWheelchairAccess,
      'has_parking': hasParking,
      'photo_url': photoUrl,
      'status': status,
      'verified_count': verifiedCount,
      'distance_meters': distanceMeters,
    };
  }
}
