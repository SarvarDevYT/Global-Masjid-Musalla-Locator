import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../widgets/navigation_dialog.dart';
import '../../data/models/mosque_model.dart';
import '../../providers/locale_provider.dart';
import '../../providers/mosque_providers.dart';
import '../widgets/mosque_detail_sheet.dart';
import '../widgets/skeleton_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_mosque_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLocating = false;
  int _cooldownRemainingMinutes = 0;
  static const int _scanCooldownMinutes = 10;
  static const String _lastScanKey = 'last_full_scan_timestamp';

  @override
  void initState() {
    super.initState();
    _checkCooldown();
  }

  Future<void> _checkCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScan = prefs.getInt(_lastScanKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - lastScan;
      final cooldownMs = _scanCooldownMinutes * 60 * 1000;
      if (elapsed < cooldownMs) {
        if (mounted) {
          setState(() {
            _cooldownRemainingMinutes = ((cooldownMs - elapsed) / 60000).ceil();
          });
        }
      } else {
        if (mounted && _cooldownRemainingMinutes > 0) {
          setState(() {
            _cooldownRemainingMinutes = 0;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectNearbyMosques({bool forceDeepScan = false}) async {
    setState(() => _isLocating = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScan = prefs.getInt(_lastScanKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedMs = now - lastScan;
      final cooldownMs = _scanCooldownMinutes * 60 * 1000;
      final isInCooldown = elapsedMs < cooldownMs && !forceDeepScan;

      await ref.read(userLocationProvider.notifier).refreshLocation();
      final loc = ref.read(userLocationProvider).value;

      if (loc == null) {
        ref.invalidate(mosquesListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Joylashuvni aniqlab bo\'lmadi. GPS yoqilganligini tekshiring.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (isInCooldown) {
        // Cooldown active (within 10 minutes): instant refresh from DB/cache and notify user
        final remainingMinutes = ((cooldownMs - elapsedMs) / 60000).ceil();
        await ref.read(mosquesListProvider.notifier).searchInCustomArea(loc);

        if (mounted) {
          setState(() => _cooldownRemainingMinutes = remainingMinutes);
          final count = ref.read(mosquesListProvider).value?.length ?? 0;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⏱️ Yaqin masjidlar ko\'rsatildi ($count ta).\nYangi to\'liq skanerlash $remainingMinutes daqiqadan so\'ng mumkin.',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Cooldown passed: Full scan & auto-sync new mosques into database!
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('Hudud skanerlanmoqda va yangi masjidlar tekshirilmoqda...')),
                ],
              ),
              duration: Duration(seconds: 4),
              backgroundColor: AppColors.primary,
            ),
          );
        }

        final scanResult = await ref.read(mosquesListProvider.notifier).scanAndSyncArea(loc);
        await prefs.setInt(_lastScanKey, now);

        if (mounted) {
          setState(() => _cooldownRemainingMinutes = _scanCooldownMinutes);
          final count = ref.read(mosquesListProvider).value?.length ?? 0;
          final newlyAdded = scanResult.newlyAddedCount;

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      newlyAdded > 0
                          ? '✅ $count ta yaqin masjid topildi ($newlyAdded ta yangi masjid bazaga kiritildi)!'
                          : '✅ Atrofdagi $count ta yaqin masjid to\'liq yangilandi!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final mosquesAsync = ref.watch(mosquesListProvider);
    final filters = ref.watch(filtersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            height: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.mosque, color: AppColors.goldLight, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              AppTranslations.get('app_title', locale),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                  )
                : const Icon(Icons.radar, color: AppColors.primaryLight),
            tooltip: _cooldownRemainingMinutes > 0
                ? 'Kutish: $_cooldownRemainingMinutes daq'
                : 'Yaqin masjidlarni skanerlash',
            onPressed: _isLocating ? null : _detectNearbyMosques,
          ),
          IconButton(
            icon: const Icon(Icons.add_location_alt, color: AppColors.primaryLight),
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
          await _detectNearbyMosques();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. QUICK SERVICES (4 Cards: Qibla, Map, Add Mosque, Settings)
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

  // Quick Services Grid
  Widget _buildQuickServicesGrid(BuildContext context, String locale, bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        // 1. Qibla Compass (Imperial Islamic Gold)
        _buildServiceCard(
          title: 'Qibla Kompasi',
          subtitle: 'Ka\'ba tomon yo\'nalish',
          icon: Icons.explore,
          gradient: const [Color(0xFFB78B1E), Color(0xFFD4AF37), Color(0xFFFDE68A)],
          borderColor: AppColors.goldLight.withValues(alpha: 0.6),
          onTap: () {
            ref.read(currentTabProvider.notifier).state = 2; // Switch to Qibla Tab
          },
        ),

        // 2. Map Explorer (Royal Islamic Emerald)
        _buildServiceCard(
          title: 'Xarita & Navigator',
          subtitle: 'Xaritada ko\'rish',
          icon: Icons.map,
          gradient: const [Color(0xFF044332), Color(0xFF065F46), Color(0xFF0D9488)],
          borderColor: AppColors.primaryLight.withValues(alpha: 0.5),
          onTap: () {
            ref.read(currentTabProvider.notifier).state = 1; // Switch to Map Tab
          },
        ),

        // 3. Add Mosque (Islamic Malachite)
        _buildServiceCard(
          title: 'Masjid Qo\'shish',
          subtitle: 'Yangi joy kiritish',
          icon: Icons.add_business,
          gradient: const [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF10B981)],
          borderColor: AppColors.gold.withValues(alpha: 0.4),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMosqueScreen()),
            );
          },
        ),

        // 4. Settings (Ka'ba Kiswah Midnight Slate)
        _buildServiceCard(
          title: 'Sozlamalar',
          subtitle: 'Til va oflayn kesh',
          icon: Icons.settings,
          gradient: const [Color(0xFF0B2125), Color(0xFF153940), Color(0xFF1E4B54)],
          borderColor: isDark ? AppColors.darkCardBorder : Colors.white24,
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
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.35),
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
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 13),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
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
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: AppTranslations.get('search_hint', locale),
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.primaryLight),
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
      height: 38,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.lightCardBorder,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.lightTextSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: mosque.isMasjid ? AppColors.emeraldGradient : AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: mosque.isMasjid ? AppColors.gold : AppColors.goldLight,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (mosque.isMasjid ? AppColors.primary : AppColors.gold).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1),
                ),
                child: Text(
                  '📍 $distText',
                  style: TextStyle(
                    color: isDark ? AppColors.goldLight : AppColors.goldDark,
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
              _buildTag('💧 Tahoratxona', mosque.hasWuduMen, isDark),
              if (mosque.hasWuduWomen) _buildTag('🧕 Ayollar tahoratxonasi', true, isDark),
              if (mosque.hasWomenPrayerArea) _buildTag('🧕 Ayollar zali', true, isDark),
              if (mosque.hasJuma) _buildTag('🕌 Juma o\'qiladi', true, isDark),
              if (mosque.hasParking) _buildTag('🚗 Avtoturargoh', true, isDark),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
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
                    elevation: 1,
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
                  foregroundColor: isDark ? AppColors.goldLight : AppColors.primary,
                  side: BorderSide(
                    color: isDark ? AppColors.gold.withValues(alpha: 0.5) : AppColors.primaryLight,
                  ),
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
                color: AppColors.gold,
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

  Widget _buildTag(String text, bool active, [bool isDark = false]) {
    if (!active) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primaryDark.withValues(alpha: 0.35)
            : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? AppColors.primaryLight.withValues(alpha: 0.25)
              : AppColors.primary.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mosque_outlined, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'Yaqin-atrofda masjid topilmadi',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'GPS joylashuvingizni yangilang yoki boshqa hududni skanerlang.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              ref.read(userLocationProvider.notifier).refreshLocation();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Qayta qidirish', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
