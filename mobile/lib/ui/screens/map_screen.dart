import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../core/utils/geo_utils.dart';
import '../../providers/locale_provider.dart';
import '../../providers/mosque_providers.dart';
import '../widgets/map_widget.dart';
import '../widgets/mosque_card.dart';
import '../widgets/mosque_detail_sheet.dart';
import '../widgets/navigation_dialog.dart';
import '../widgets/skeleton_loader.dart';
import 'add_mosque_screen.dart';
import 'qibla_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
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
      ref.read(allMosquesProvider.notifier).setCenter(_currentCenter!);
      setState(() => _showSearchAreaButton = false);
    }
  }

  Future<void> _recenterToUser() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('📍 Joylashuv aniqlanmoqda...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );

    await ref.read(userLocationProvider.notifier).refreshLocation();
    final userLoc = ref.read(userLocationProvider).value;
    if (userLoc != null) {
      _mapController.move(userLoc, 15.0);
      ref.read(allMosquesProvider.notifier).resetToUserLocation();
      setState(() => _showSearchAreaButton = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final userLocationAsync = ref.watch(userLocationProvider);
    final mosquesAsync = ref.watch(allMosquesProvider);
    final filters = ref.watch(filtersProvider);
    final selectedMosque = ref.watch(selectedMosqueProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final LatLng initialCenter = userLocationAsync.value ?? const LatLng(41.3381, 69.2415);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Map
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
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
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
                      onChanged: (val) {
                        ref.read(filtersProvider.notifier).setSearchQuery(val.trim());
                      },
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
                          isDark: isDark,
                          onTap: () => ref.read(filtersProvider.notifier).setType('all'),
                        ),
                        _buildFilterBadge(
                          label: AppTranslations.get('masjid', locale),
                          isSelected: filters.type == 'masjid',
                          isDark: isDark,
                          onTap: () => ref.read(filtersProvider.notifier).setType(
                                filters.type == 'masjid' ? 'all' : 'masjid',
                              ),
                        ),
                        _buildFilterBadge(
                          label: AppTranslations.get('musalla', locale),
                          isSelected: filters.type == 'musalla',
                          isDark: isDark,
                          onTap: () => ref.read(filtersProvider.notifier).setType(
                                filters.type == 'musalla' ? 'all' : 'musalla',
                              ),
                        ),
                        _buildFilterBadge(
                          label: AppTranslations.get('women_friendly', locale),
                          isSelected: filters.hasWuduWomen || filters.hasWomenPrayerArea,
                          isDark: isDark,
                          onTap: () {
                            ref.read(filtersProvider.notifier).toggleWomenPrayer();
                            ref.read(filtersProvider.notifier).toggleWuduWomen();
                          },
                        ),
                      ],
                    ),
                  ),

                  // "Search this area" button
                  if (_showSearchAreaButton) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                        foregroundColor: AppColors.primary,
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: _searchThisArea,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(
                        AppTranslations.get('search_this_area', locale),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. RIGHT FLOATING ACTION BUTTONS
          Positioned(
            right: 16,
            top: 175,
            child: Column(
              children: [
                _buildFloatingButton(
                  icon: Icons.explore_outlined,
                  color: isDark ? AppColors.darkCard : Colors.white,
                  iconColor: AppColors.gold,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QiblaScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  icon: Icons.my_location,
                  color: isDark ? AppColors.darkCard : Colors.white,
                  iconColor: AppColors.primary,
                  onPressed: _recenterToUser,
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  icon: Icons.add,
                  color: AppColors.primary,
                  iconColor: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddMosqueScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          // 4. SELECTED MOSQUE BOTTOM CARD (Matches PDF Page 2)
          if (selectedMosque != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Name & Distance
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedMosque.name,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedMosque.address.isNotEmpty
                                    ? selectedMosque.address
                                    : (selectedMosque.city ?? ''),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (selectedMosque.distanceMeters != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              GeoUtils.formatDistance(selectedMosque.distanceMeters!),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          onPressed: () {
                            ref.read(selectedMosqueProvider.notifier).state = null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Action buttons: "Yo'nalish olish" & "Batafsil"
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                NavigationDialog.show(
                                  context,
                                  lat: selectedMosque.lat,
                                  lng: selectedMosque.lng,
                                  title: selectedMosque.name,
                                  locale: locale,
                                );
                              },
                              icon: const Icon(Icons.navigation, size: 16),
                              label: Text(
                                AppTranslations.get('navigate', locale),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                side: BorderSide(
                                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                MosqueDetailSheet.show(
                                  context,
                                  mosque: selectedMosque,
                                  locale: locale,
                                  onReportSubmit: (id, reason, details) =>
                                      ref.read(mosqueRepositoryProvider).reportIssue(id, reason, details),
                                );
                              },
                              child: Text(
                                AppTranslations.get('details', locale),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            // 5. BOTTOM DRAGGABLE SHEET (When no mosque selected)
            DraggableScrollableSheet(
              initialChildSize: 0.16,
              minChildSize: 0.08,
              maxChildSize: 0.65,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 10),
                                width: 44,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppTranslations.get('nearby_mosques', locale),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  mosquesAsync.when(
                                    data: (list) => Text(
                                      '${list.length} ta',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, __) => const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 16),
                          ],
                        ),
                      ),
                      mosquesAsync.when(
                        data: (list) {
                          if (list.isEmpty) {
                            return SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    AppTranslations.get('no_mosques_found', locale),
                                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                ),
                              ),
                            );
                          }
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final mosque = list[index];
                                return MosqueCard(
                                  mosque: mosque,
                                  locale: locale,
                                  onTap: () {
                                    ref.read(selectedMosqueProvider.notifier).state = mosque;
                                    _mapController.move(LatLng(mosque.lat, mosque.lng), 16.0);
                                  },
                                );
                              },
                              childCount: list.length,
                            ),
                          );
                        },
                        loading: () => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: List.generate(4, (_) => const SkeletonLoader()),
                            ),
                          ),
                        ),
                        error: (_, __) => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                AppTranslations.get('error_network', locale),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      ),
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
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 22),
        onPressed: onPressed,
      ),
    );
  }

  void _openFilterModal(BuildContext context, String locale) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final filters = ref.watch(filtersProvider);
            final notifier = ref.read(filtersProvider.notifier);

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filtrlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          notifier.resetFilters();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Tozalash'),
                      ),
                    ],
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppTranslations.get('filter_women_wudu', locale)),
                    value: filters.hasWuduWomen,
                    onChanged: (_) => notifier.toggleWuduWomen(),
                  ),
                  SwitchListTile(
                    title: Text(AppTranslations.get('filter_women_prayer', locale)),
                    value: filters.hasWomenPrayerArea,
                    onChanged: (_) => notifier.toggleWomenPrayer(),
                  ),
                  SwitchListTile(
                    title: Text(AppTranslations.get('filter_juma', locale)),
                    value: filters.hasJuma,
                    onChanged: (_) => notifier.toggleJuma(),
                  ),
                  SwitchListTile(
                    title: Text(AppTranslations.get('filter_wheelchair', locale)),
                    value: filters.hasWheelchairAccess,
                    onChanged: (_) => notifier.toggleWheelchair(),
                  ),
                  SwitchListTile(
                    title: Text(AppTranslations.get('filter_parking', locale)),
                    value: filters.hasParking,
                    onChanged: (_) => notifier.toggleParking(),
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
