import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/mosque_providers.dart';
import '../widgets/map_widget.dart';
import '../widgets/mosque_card.dart';
import '../widgets/mosque_detail_sheet.dart';
import '../widgets/skeleton_loader.dart';
import 'add_mosque_screen.dart';
import 'qibla_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng? _currentCenter;
  bool _showSearchAreaButton = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onPositionChanged(LatLng newCenter) {
    _currentCenter = newCenter;
    final userLoc = ref.read(userLocationProvider).value;
    if (userLoc != null) {
      final double latDiff = (newCenter.latitude - userLoc.latitude).abs();
      final double lngDiff = (newCenter.longitude - userLoc.longitude).abs();
      if (latDiff > 0.02 || lngDiff > 0.02) {
        if (!_showSearchAreaButton) {
          setState(() => _showSearchAreaButton = true);
        }
      }
    }
  }

  void _searchThisArea() {
    if (_currentCenter != null) {
      ref.read(mosquesListProvider.notifier).searchInCustomArea(_currentCenter!);
      setState(() => _showSearchAreaButton = false);
    }
  }

  void _recenterToUser() {
    final userLoc = ref.read(userLocationProvider).value;
    if (userLoc != null) {
      _mapController.move(userLoc, 15.0);
      ref.read(mosquesListProvider.notifier).searchInCustomArea(userLoc);
      setState(() => _showSearchAreaButton = false);
    } else {
      ref.read(userLocationProvider.notifier).refreshLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final userLocationAsync = ref.watch(userLocationProvider);
    final mosquesAsync = ref.watch(mosquesListProvider);
    final filters = ref.watch(filtersProvider);
    final selectedMosque = ref.watch(selectedMosqueProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final LatLng initialCenter = userLocationAsync.value ?? const LatLng(41.3381, 69.2415);

    return Scaffold(
      body: Stack(
        children: [
          // 1. TOP HALF: Interactive OpenStreetMap
          Positioned.fill(
            child: MapWidget(
              mapController: _mapController,
              initialCenter: initialCenter,
              userLocation: userLocationAsync.value,
              mosques: mosquesAsync.value ?? [],
              selectedMosque: selectedMosque,
              onMosqueSelected: (mosque) {
                ref.read(selectedMosqueProvider.notifier).state = mosque;
                _mapController.move(LatLng(mosque.lat, mosque.lng), 16.0);
                MosqueDetailSheet.show(
                  context,
                  mosque: mosque,
                  locale: locale,
                  onReportSubmit: (id, reason, details) =>
                      ref.read(mosqueRepositoryProvider).reportIssue(id, reason, details),
                );
              },
              onPositionChanged: _onPositionChanged,
            ),
          ),

          // 2. TOP FLOATING APP BAR & SEARCH
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search Bar Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: AppTranslations.get('search_hint', locale),
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(filtersProvider.notifier).setSearchQuery('');
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.tune, color: AppColors.primary),
                              onPressed: () => _openFilterModal(context, locale),
                            ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: (val) {
                        ref.read(filtersProvider.notifier).setSearchQuery(val.trim());
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Quick Filter Horizontal Scroll
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterBadge(
                          label: AppTranslations.get('all', locale),
                          isSelected: filters.type == 'all',
                          onTap: () => ref.read(filtersProvider.notifier).setType('all'),
                        ),
                        _buildFilterBadge(
                          label: AppTranslations.get('masjid', locale),
                          isSelected: filters.type == 'masjid',
                          onTap: () => ref.read(filtersProvider.notifier).setType(
                                filters.type == 'masjid' ? 'all' : 'masjid',
                              ),
                        ),
                        _buildFilterBadge(
                          label: AppTranslations.get('musalla', locale),
                          isSelected: filters.type == 'musalla',
                          onTap: () => ref.read(filtersProvider.notifier).setType(
                                filters.type == 'musalla' ? 'all' : 'musalla',
                              ),
                        ),
                        _buildFilterBadge(
                          label: AppTranslations.get('filter_women_prayer', locale),
                          isSelected: filters.hasWomenPrayerArea,
                          onTap: () => ref.read(filtersProvider.notifier).toggleWomenPrayer(),
                        ),
                        _buildFilterBadge(
                          label: AppTranslations.get('filter_women_wudu', locale),
                          isSelected: filters.hasWuduWomen,
                          onTap: () => ref.read(filtersProvider.notifier).toggleWuduWomen(),
                        ),
                        _buildFilterBadge(
                          label: AppTranslations.get('filter_juma', locale),
                          isSelected: filters.hasJuma,
                          onTap: () => ref.read(filtersProvider.notifier).toggleJuma(),
                        ),
                        _buildFilterBadge(
                          label: AppTranslations.get('filter_wheelchair', locale),
                          isSelected: filters.hasWheelchairAccess,
                          onTap: () => ref.read(filtersProvider.notifier).toggleWheelchair(),
                        ),
                        _buildFilterBadge(
                          label: AppTranslations.get('filter_parking', locale),
                          isSelected: filters.hasParking,
                          onTap: () => ref.read(filtersProvider.notifier).toggleParking(),
                        ),
                      ],
                    ),
                  ),

                  // Floating "Search this area" Button
                  if (_showSearchAreaButton)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ElevatedButton.icon(
                        onPressed: _searchThisArea,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(
                          AppTranslations.get('search_this_area', locale),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. FLOATING ACTION BUTTONS (Map Controls & Navigation)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.32,
            child: Column(
              children: [
                // Qibla Compass
                FloatingActionButton.small(
                  heroTag: 'fab_qibla',
                  backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                  foregroundColor: AppColors.accentGold,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QiblaScreen()),
                    );
                  },
                  child: const Icon(Icons.explore),
                ),
                const SizedBox(height: 10),

                // Recenter My Location
                FloatingActionButton.small(
                  heroTag: 'fab_location',
                  backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: _recenterToUser,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 10),

                // Add Mosque (Crowdsourcing)
                FloatingActionButton.small(
                  heroTag: 'fab_add',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddMosqueScreen()),
                    );
                  },
                  child: const Icon(Icons.add_location_alt),
                ),
                const SizedBox(height: 10),

                // Settings
                FloatingActionButton.small(
                  heroTag: 'fab_settings',
                  backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                  foregroundColor: Colors.grey.shade700,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  child: const Icon(Icons.settings),
                ),
              ],
            ),
          ),

          // 4. BOTTOM DRAGGABLE SCROLLABLE SHEET (Split View)
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.16,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Sheet Grab Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header Info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppTranslations.get('nearby_mosques', locale),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${mosquesAsync.value?.length ?? 0} ta',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mosques Content: Loading Skeleton or Mosque Cards
                    mosquesAsync.when(
                      loading: () => Column(
                        children: const [
                          MosqueCardSkeleton(),
                          MosqueCardSkeleton(),
                          MosqueCardSkeleton(),
                        ],
                      ),
                      error: (err, stack) => Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(child: Text('Xatolik: $err')),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.mosque, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Ushbu hududda masjidlar topilmadi',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Xaritani siljitib "Ushbu hududdan qidirish" tugmasini bosing yoki yangi masjid qo\'shing.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: list.map((m) {
                            return MosqueCard(
                              mosque: m,
                              locale: locale,
                              onTap: () {
                                ref.read(selectedMosqueProvider.notifier).state = m;
                                _mapController.move(LatLng(m.lat, m.lng), 16.0);
                                MosqueDetailSheet.show(
                                  context,
                                  mosque: m,
                                  locale: locale,
                                  onReportSubmit: (id, reason, details) =>
                                      ref.read(mosqueRepositoryProvider).reportIssue(id, reason, details),
                                );
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBadge({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : null,
        ),
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        onSelected: (_) => onTap(),
      ),
    );
  }

  void _openFilterModal(BuildContext context, String locale) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final f = ref.watch(filtersProvider);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Batafsil Filtrlash', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(AppTranslations.get('filter_women_prayer', locale)),
                    value: f.hasWomenPrayerArea,
                    onChanged: (_) => ref.read(filtersProvider.notifier).toggleWomenPrayer(),
                  ),
                  SwitchListTile(
                    title: Text(AppTranslations.get('filter_women_wudu', locale)),
                    value: f.hasWuduWomen,
                    onChanged: (_) => ref.read(filtersProvider.notifier).toggleWuduWomen(),
                  ),
                  SwitchListTile(
                    title: Text(AppTranslations.get('filter_juma', locale)),
                    value: f.hasJuma,
                    onChanged: (_) => ref.read(filtersProvider.notifier).toggleJuma(),
                  ),
                  SwitchListTile(
                    title: Text(AppTranslations.get('filter_wheelchair', locale)),
                    value: f.hasWheelchairAccess,
                    onChanged: (_) => ref.read(filtersProvider.notifier).toggleWheelchair(),
                  ),
                  SwitchListTile(
                    title: Text(AppTranslations.get('filter_parking', locale)),
                    value: f.hasParking,
                    onChanged: (_) => ref.read(filtersProvider.notifier).toggleParking(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tayyor'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
