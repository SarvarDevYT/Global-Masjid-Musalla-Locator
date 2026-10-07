import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../data/models/mosque_model.dart';
import '../data/repositories/mosque_repository.dart';
import '../data/services/location_service.dart';

// Repository instance provider
final mosqueRepositoryProvider = Provider<MosqueRepository>((ref) {
  return MosqueRepository();
});

// User location provider
final userLocationProvider = StateNotifierProvider<UserLocationNotifier, AsyncValue<LatLng>>((ref) {
  return UserLocationNotifier();
});

class UserLocationNotifier extends StateNotifier<AsyncValue<LatLng>> {
  UserLocationNotifier() : super(const AsyncValue.loading()) {
    refreshLocation();
  }

  Future<void> refreshLocation() async {
    state = const AsyncValue.loading();
    try {
      final loc = await LocationService.getCurrentLocation();
      state = AsyncValue.data(LatLng(loc.lat, loc.lng));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void setManualLocation(LatLng loc) {
    state = AsyncValue.data(loc);
  }
}

// Map center tracking provider
final mapCenterProvider = StateProvider<LatLng?>((ref) => null);

// Show "Search This Area" button state
final showSearchThisAreaProvider = StateProvider<bool>((ref) => false);

// Filter model
class MosqueFilters {
  final String type; // 'all', 'masjid', 'musalla'
  final bool hasWuduWomen;
  final bool hasWomenPrayerArea;
  final bool hasJuma;
  final bool hasWheelchairAccess;
  final bool hasParking;
  final String searchQuery;

  const MosqueFilters({
    this.type = 'all',
    this.hasWuduWomen = false,
    this.hasWomenPrayerArea = false,
    this.hasJuma = false,
    this.hasWheelchairAccess = false,
    this.hasParking = false,
    this.searchQuery = '',
  });

  MosqueFilters copyWith({
    String? type,
    bool? hasWuduWomen,
    bool? hasWomenPrayerArea,
    bool? hasJuma,
    bool? hasWheelchairAccess,
    bool? hasParking,
    String? searchQuery,
  }) {
    return MosqueFilters(
      type: type ?? this.type,
      hasWuduWomen: hasWuduWomen ?? this.hasWuduWomen,
      hasWomenPrayerArea: hasWomenPrayerArea ?? this.hasWomenPrayerArea,
      hasJuma: hasJuma ?? this.hasJuma,
      hasWheelchairAccess: hasWheelchairAccess ?? this.hasWheelchairAccess,
      hasParking: hasParking ?? this.hasParking,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final filtersProvider = StateNotifierProvider<FiltersNotifier, MosqueFilters>((ref) {
  return FiltersNotifier();
});

class FiltersNotifier extends StateNotifier<MosqueFilters> {
  FiltersNotifier() : super(const MosqueFilters());

  void setType(String type) => state = state.copyWith(type: type);
  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);
  void toggleWuduWomen() => state = state.copyWith(hasWuduWomen: !state.hasWuduWomen);
  void toggleWomenPrayer() => state = state.copyWith(hasWomenPrayerArea: !state.hasWomenPrayerArea);
  void toggleJuma() => state = state.copyWith(hasJuma: !state.hasJuma);
  void toggleWheelchair() => state = state.copyWith(hasWheelchairAccess: !state.hasWheelchairAccess);
  void toggleParking() => state = state.copyWith(hasParking: !state.hasParking);

  void resetFilters() => state = const MosqueFilters();
}

// Selected Mosque provider
final selectedMosqueProvider = StateProvider<MosqueModel?>((ref) => null);

// Mosques list provider
final mosquesListProvider = AsyncNotifierProvider<MosquesListNotifier, List<MosqueModel>>(() {
  return MosquesListNotifier();
});

class MosquesListNotifier extends AsyncNotifier<List<MosqueModel>> {
  @override
  Future<List<MosqueModel>> build() async {
    final locationAsync = ref.watch(userLocationProvider);
    final filters = ref.watch(filtersProvider);
    final repo = ref.watch(mosqueRepositoryProvider);

    final LatLng center = locationAsync.value ?? const LatLng(41.3381, 69.2415);

    return await repo.getNearbyMosques(
      userLat: center.latitude,
      userLng: center.longitude,
      radiusMeters: 25000,
      type: filters.type,
      query: filters.searchQuery,
      hasWuduWomen: filters.hasWuduWomen,
      hasWomenPrayerArea: filters.hasWomenPrayerArea,
      hasJuma: filters.hasJuma,
      hasWheelchairAccess: filters.hasWheelchairAccess,
      hasParking: filters.hasParking,
    );
  }

  Future<void> searchInCustomArea(LatLng newCenter) async {
    state = const AsyncValue.loading();
    try {
      final filters = ref.read(filtersProvider);
      final repo = ref.read(mosqueRepositoryProvider);

      final list = await repo.getNearbyMosques(
        userLat: newCenter.latitude,
        userLng: newCenter.longitude,
        radiusMeters: 25000,
        type: filters.type,
        query: filters.searchQuery,
        hasWuduWomen: filters.hasWuduWomen,
        hasWomenPrayerArea: filters.hasWomenPrayerArea,
        hasJuma: filters.hasJuma,
        hasWheelchairAccess: filters.hasWheelchairAccess,
        hasParking: filters.hasParking,
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
