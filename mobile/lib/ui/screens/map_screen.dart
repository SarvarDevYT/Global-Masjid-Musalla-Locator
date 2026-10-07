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
      ref.read(mosquesListProvider.notifier).searchInCustomArea(_currentCenter!);
      setState(() => _showSearchAreaButton = false);
    }
  }

  Future<void> _recenterToUser() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📍 Joylashuvingiz va yaqin masjidlar aniqlanmoqda...'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );

    await ref.read(userLocationProvider.notifier).refreshLocation();
    final userLoc = ref.read(userLocationProvider).value;
    if (userLoc != null) {
      _mapController.move(userLoc, 15.0);
      await ref.read(mosquesListProvider.notifier).searchInCustomArea(userLoc);
      setState(() => _showSearchAreaButton = false);
      if (mounted) {
        final count = ref.read(mosquesListProvider).value?.length ?? 0;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $count ta yaqin masjid ko\'rsatildi'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
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
          // 1. Interactive OpenStreetMap / CartoDB
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
                          label: '💧 ${AppTranslations.get('filter_women_wudu', locale)}',
                          isSelected: filters.hasWuduWomen,
                          onTap: () => ref.read(filtersProvider.notifier).toggleWuduWomen(),
                        ),
                        _buildFilterBadge(
                          label: '🧕 ${AppTranslations.get('filter_women_prayer', locale)}',
                          isSelected: filters.hasWomenPrayerArea,
                          onTap: () => ref.read(filtersProvider.notifier).toggleWomenPrayer(),
                        ),
                      ],
                    ),
                  ),

                  // Search this area button
                  if (_showSearchAreaButton) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
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
            top: 180,
            child: Column(
              children: [
                _buildFloatingButton(
                  icon: Icons.explore,
                  color: AppColors.accentGold,
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
                  color: AppColors.darkCard,
                  onPressed: _recenterToUser,
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  icon: Icons.add_location_alt,
                  color: AppColors.primary,
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

          // 4. BOTTOM DRAGGABLE SHEET
          DraggableScrollableSheet(
            initialChildSize: 0.18,
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
                                  'Yaqin-atrofda masjid topilmadi',
                                  style: TextStyle(color: Colors.grey.shade600),
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
                                  MosqueDetailSheet.show(
                                    context,
                                    mosque: mosque,
                                    locale: locale,
                                    onReportSubmit: (id, reason, details) =>
                                        ref.read(mosqueRepositoryProvider).reportIssue(id, reason, details),
                                  );
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
                      error: (err, _) => SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Xatolik: $err',
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
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
