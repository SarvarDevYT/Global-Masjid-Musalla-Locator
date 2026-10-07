import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../widgets/navigation_dialog.dart';
import '../../data/models/mosque_model.dart';
import '../../providers/locale_provider.dart';
import '../../providers/mosque_providers.dart';
import '../widgets/mosque_detail_sheet.dart';
import '../widgets/skeleton_loader.dart';
import 'add_mosque_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final userLocationAsync = ref.watch(userLocationProvider);
    final mosquesAsync = ref.watch(mosquesListProvider);
    final filters = ref.watch(filtersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D131F) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF047857)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mosque, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.get('app_title', locale),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Global Musalla Locator',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt, color: AppColors.primary),
            tooltip: AppTranslations.get('add_mosque', locale),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMosqueScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(userLocationProvider.notifier).refreshLocation();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. LOCATION & GPS STATUS CARD
            _buildLocationStatusCard(context, userLocationAsync, isDark),

            const SizedBox(height: 18),

            // 2. QUICK SERVICES (4 Cards: Qibla, Map, Add Mosque, Settings)
            Text(
              'Asosiy Xizmatlar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            _buildQuickServicesGrid(context, locale, isDark),

            const SizedBox(height: 20),

            // 3. SEARCH & QUICK FILTERS
            _buildSearchBar(isDark, locale),
            const SizedBox(height: 10),
            _buildFilterChips(filters, locale),

            const SizedBox(height: 20),

            // 4. NEAREST MOSQUES FEED
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppTranslations.get('nearby_mosques', locale),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                mosquesAsync.when(
                  data: (list) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${list.length} ta',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mosques List Content
            mosquesAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return _buildEmptyState(isDark);
                }
                return Column(
                  children: list.map((m) => _buildMosqueFeedCard(context, m, isDark, locale)).toList(),
                );
              },
              loading: () => Column(
                children: List.generate(3, (_) => const SkeletonLoader()),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('Xatolik: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Location Card
  Widget _buildLocationStatusCard(
    BuildContext context,
    AsyncValue<LatLng> userLocAsync,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF111827)]
              : [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sizning Joylashuvingiz',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                userLocAsync.when(
                  data: (pos) => Text(
                    'GPS: ${pos.latitude.toStringAsFixed(4)}°, ${pos.longitude.toStringAsFixed(4)}°',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  loading: () => const Text(
                    'GPS aniqlanmoqda...',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                  error: (_, __) => const Text(
                    'Standart hudud (Toshkent)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            onPressed: () {
              ref.read(userLocationProvider.notifier).refreshLocation();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Yangilash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Quick Services Grid
  Widget _buildQuickServicesGrid(BuildContext context, String locale, bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        // 1. Qibla Compass
        _buildServiceCard(
          title: 'Qibla Kompasi',
          subtitle: 'Ka\'ba tomon yo\'nalish',
          icon: Icons.explore,
          gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          onTap: () {
            ref.read(currentTabProvider.notifier).state = 2; // Switch to Qibla Tab
          },
        ),

        // 2. Map Explorer
        _buildServiceCard(
          title: 'Xarita & Navigator',
          subtitle: 'Xaritada ko\'rish',
          icon: Icons.map,
          gradient: const [Color(0xFF10B981), Color(0xFF059669)],
          onTap: () {
            ref.read(currentTabProvider.notifier).state = 1; // Switch to Map Tab
          },
        ),

        // 3. Add Mosque
        _buildServiceCard(
          title: 'Masjid Qo\'shish',
          subtitle: 'Yangi joy kiritish',
          icon: Icons.add_business,
          gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMosqueScreen()),
            );
          },
        ),

        // 4. Settings
        _buildServiceCard(
          title: 'Sozlamalar',
          subtitle: 'Til va oflayn kesh',
          icon: Icons.settings,
          gradient: const [Color(0xFF6B7280), Color(0xFF374151)],
          onTap: () {
            ref.read(currentTabProvider.notifier).state = 3; // Switch to Settings Tab
          },
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Search Bar
  Widget _buildSearchBar(bool isDark, String locale) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: AppTranslations.get('search_hint', locale),
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (val) {
          ref.read(filtersProvider.notifier).setSearchQuery(val.trim());
        },
      ),
    );
  }

  // Filter Chips
  Widget _buildFilterChips(MosqueFilters filters, String locale) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildChip(
            label: AppTranslations.get('all', locale),
            isSelected: filters.type == 'all',
            onTap: () => ref.read(filtersProvider.notifier).setType('all'),
          ),
          _buildChip(
            label: AppTranslations.get('masjid', locale),
            isSelected: filters.type == 'masjid',
            onTap: () => ref.read(filtersProvider.notifier).setType(
                  filters.type == 'masjid' ? 'all' : 'masjid',
                ),
          ),
          _buildChip(
            label: AppTranslations.get('musalla', locale),
            isSelected: filters.type == 'musalla',
            onTap: () => ref.read(filtersProvider.notifier).setType(
                  filters.type == 'musalla' ? 'all' : 'musalla',
                ),
          ),
          _buildChip(
            label: '💧 ${AppTranslations.get('filter_women_wudu', locale)}',
            isSelected: filters.hasWuduWomen,
            onTap: () => ref.read(filtersProvider.notifier).toggleWuduWomen(),
          ),
          _buildChip(
            label: '🧕 ${AppTranslations.get('filter_women_prayer', locale)}',
            isSelected: filters.hasWomenPrayerArea,
            onTap: () => ref.read(filtersProvider.notifier).toggleWomenPrayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // Mosque Feed Card
  Widget _buildMosqueFeedCard(
    BuildContext context,
    MosqueModel mosque,
    bool isDark,
    String locale,
  ) {
    final distText = mosque.formattedDistance;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: mosque.isMasjid
                        ? [const Color(0xFF10B981), const Color(0xFF047857)]
                        : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  mosque.isMasjid ? Icons.mosque : Icons.meeting_room,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mosque.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mosque.address.isNotEmpty ? mosque.address : (mosque.city ?? 'Manzil ko\'rsatilmagan'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '📍 $distText',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Amenities row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTag('💧 Tahoratxona', mosque.hasWuduMen),
              if (mosque.hasWuduWomen) _buildTag('🧕 Ayollar tahoratxonasi', true),
              if (mosque.hasWomenPrayerArea) _buildTag('🧕 Ayollar zali', true),
              if (mosque.hasJuma) _buildTag('🕌 Juma o\'qiladi', true),
              if (mosque.hasParking) _buildTag('🚗 Avtoturargoh', true),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Actions: Borish & Xaritada ko'rish
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                  onPressed: () {
                    NavigationDialog.show(
                      context,
                      lat: mosque.lat,
                      lng: mosque.lng,
                      title: mosque.name,
                      locale: locale,
                    );
                  },
                  icon: const Icon(Icons.navigation, size: 16),
                  label: const Text('Borish (Navigatsiya)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () {
                  ref.read(selectedMosqueProvider.notifier).state = mosque;
                  ref.read(currentTabProvider.notifier).state = 1; // Switch to Map
                },
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Xarita', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                color: Colors.grey,
                onPressed: () {
                  MosqueDetailSheet.show(
                    context,
                    mosque: mosque,
                    locale: locale,
                    onReportSubmit: (id, reason, details) =>
                        ref.read(mosqueRepositoryProvider).reportIssue(id, reason, details),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, bool active) {
    if (!active) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.location_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'Yaqin-atrofda masjid topilmadi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'GPS joylashuvingizni yangilang yoki xaritadan qidiring.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              ref.read(userLocationProvider.notifier).refreshLocation();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Qayta qidirish'),
          ),
        ],
      ),
    );
  }
}
