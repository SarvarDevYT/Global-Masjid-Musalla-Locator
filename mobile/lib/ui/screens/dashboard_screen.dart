import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/mosque_model.dart';
import '../../providers/locale_provider.dart';
import '../../providers/mosque_providers.dart';
import '../widgets/mosque_card.dart';
import '../widgets/mosque_detail_sheet.dart';
import '../widgets/navigation_dialog.dart';
import '../widgets/skeleton_loader.dart';
import 'add_mosque_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLocating = false;
  int _cooldownRemainingSeconds = 0;
  Timer? _cooldownTimer;
  static const int _scanCooldownMinutes = 10;
  static const String _lastScanKey = 'last_full_scan_timestamp';

  @override
  void initState() {
    super.initState();
    _checkCooldown();
    // Real-time periodic timer to update countdown every 5 seconds
    _cooldownTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkCooldown();
    });
  }

  Future<void> _checkCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScan = prefs.getInt(_lastScanKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - lastScan;
      final cooldownMs = _scanCooldownMinutes * 60 * 1000;
      if (elapsed < cooldownMs) {
        final remainingSec = ((cooldownMs - elapsed) / 1000).ceil();
        if (mounted && _cooldownRemainingSeconds != remainingSec) {
          setState(() {
            _cooldownRemainingSeconds = remainingSec;
          });
        }
      } else {
        if (mounted && _cooldownRemainingSeconds > 0) {
          setState(() {
            _cooldownRemainingSeconds = 0;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
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
        // Cooldown active: instant refresh from database
        final remainingMinutes = ((cooldownMs - elapsedMs) / 60000).ceil();
        await ref.read(mosquesListProvider.notifier).searchInCustomArea(loc);

        if (mounted) {
          setState(() => _cooldownRemainingSeconds = ((cooldownMs - elapsedMs) / 1000).ceil());
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
                      '⏱️ Yaqin masjidlar yangilandi ($count ta).\nYangi to\'liq skanerlash $remainingMinutes daqiqadan so\'ng mumkin.',
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
        // Cooldown passed: Full scan & auto-sync new mosques into database
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
          setState(() => _cooldownRemainingSeconds = _scanCooldownMinutes * 60);
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
                          ? '✅ $count ta yaqin masjid topildi ($newlyAdded ta yangi masjid kiritildi)!'
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
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final remainingMins = (_cooldownRemainingSeconds / 60).ceil();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _detectNearbyMosques();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. TOP HEADER: "Assalomu alaykum" & "Yaqin masjidlar"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.get('assalomu_alaykum', locale),
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTranslations.get('nearby_mosques', locale),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Scanner button with cooldown tooltip
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: _isLocating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : Icon(
                                  Icons.radar,
                                  color: remainingMins > 0 ? Colors.grey : AppColors.primary,
                                  size: 20,
                                ),
                          tooltip: remainingMins > 0
                              ? AppTranslations.get('waiting_min', locale).replaceAll('@mins', '$remainingMins')
                              : AppTranslations.get('scan_button', locale),
                          onPressed: _isLocating ? null : _detectNearbyMosques,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add Mosque button
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: AppColors.primary, size: 22),
                          tooltip: AppTranslations.get('add_mosque', locale),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddMosqueScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. SEARCH BAR ("Masjid yoki manzil qidirish...")
              _buildSearchBar(isDark, locale),

              const SizedBox(height: 18),

              // 3. COMPACT QUICK ACTIONS (Qibla, Xarita, Qo'shish, Sozlamalar)
              _buildCompactQuickActions(context, locale, isDark),

              const SizedBox(height: 20),

              // 4. "ENG YAQIN" (Nearest Mosque) HERO CARD (PDF Page 1)
              mosquesAsync.when(
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  final nearest = list.first;
                  return Column(
                    children: [
                      _buildNearestHeroCard(context, nearest, locale),
                      const SizedBox(height: 20),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // 5. QUICK FILTER CHIPS ("Barchasi · 24", "Masjid", "Musalla", "Ayollar uchun")
              _buildFilterChips(filters, locale, isDark, mosquesAsync.value?.length ?? 0),

              const SizedBox(height: 16),

              // 6. MOSQUES LIST CONTENT
              mosquesAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return _buildEmptyState(isDark, locale);
                  }

                  // If nearest is featured as hero, show all items or remaining items cleanly
                  final displayList = list.length > 1 ? list.sublist(1) : list;

                  return Column(
                    children: displayList.map((m) {
                      return MosqueCard(
                        mosque: m,
                        locale: locale,
                        onTap: () {
                          MosqueDetailSheet.show(
                            context,
                            mosque: m,
                            locale: locale,
                            onReportSubmit: (id, reason, details) =>
                                ref.read(mosqueRepositoryProvider).reportIssue(id, reason, details),
                          );
                        },
                        onMapTap: () {
                          ref.read(selectedMosqueProvider.notifier).state = m;
                          ref.read(currentTabProvider.notifier).state = 1; // Map tab
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () => Column(
                  children: List.generate(3, (_) => const SkeletonLoader()),
                ),
                error: (_, __) => Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppTranslations.get('error_network', locale),
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- SEARCH BAR ---
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
          prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    ref.read(filtersProvider.notifier).setSearchQuery('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
        onChanged: (val) {
          ref.read(filtersProvider.notifier).setSearchQuery(val.trim());
        },
      ),
    );
  }

  // --- COMPACT QUICK ACTIONS (PDF Page 1: Qibla, Xarita, Qo'shish, Sozlamalar) ---
  Widget _buildCompactQuickActions(BuildContext context, String locale, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildQuickActionItem(
          label: AppTranslations.get('qibla', locale),
          icon: Icons.explore_outlined,
          color: AppColors.gold,
          isDark: isDark,
          onTap: () {
            ref.read(currentTabProvider.notifier).state = 2; // Qibla tab
          },
        ),
        _buildQuickActionItem(
          label: AppTranslations.get('map', locale),
          icon: Icons.map_outlined,
          color: AppColors.primary,
          isDark: isDark,
          onTap: () {
            ref.read(currentTabProvider.notifier).state = 1; // Map tab
          },
        ),
        _buildQuickActionItem(
          label: AppTranslations.get('add_mosque', locale),
          icon: Icons.add_location_alt_outlined,
          color: const Color(0xFF0D9488),
          isDark: isDark,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMosqueScreen()),
            );
          },
        ),
        _buildQuickActionItem(
          label: AppTranslations.get('settings', locale),
          icon: Icons.settings_outlined,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
          isDark: isDark,
          onTap: () {
            ref.read(currentTabProvider.notifier).state = 3; // Settings tab
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52, // >= 44px tap zone
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: color, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // --- "ENG YAQIN" (Nearest Mosque) HERO CARD (PDF Page 1) ---
  Widget _buildNearestHeroCard(BuildContext context, MosqueModel mosque, String locale) {
    final distText = mosque.distanceMeters != null
        ? GeoUtils.formatDistance(mosque.distanceMeters!)
        : (mosque.formattedDistance.isNotEmpty ? mosque.formattedDistance : '');

    final addressSubtitle = [
      if (mosque.address.isNotEmpty) mosque.address,
      if (mosque.hasWuduMen) AppTranslations.get('wudu_men', locale),
      if (mosque.hasJuma) AppTranslations.get('juma_prayer', locale),
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.emeraldGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: "ENG YAQIN" badge & Distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppTranslations.get('nearest_badge', locale),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (distText.isNotEmpty)
                Text(
                  distText,
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Mosque Title
          Text(
            mosque.name,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Subtitle / Address & Amenities
          Text(
            addressSubtitle.isNotEmpty ? addressSubtitle : (mosque.city ?? ''),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          // Large "Yo'nalish olish" Button (PDF Page 1)
          SizedBox(
            width: double.infinity,
            height: 44, // >= 44px tap zone
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              icon: const Icon(Icons.navigation, size: 16, color: AppColors.primaryDark),
              label: Text(
                AppTranslations.get('navigate', locale),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FILTER CHIPS ("Barchasi · 24", "Masjid", "Musalla", "Ayollar uchun") ---
  Widget _buildFilterChips(MosqueFilters filters, String locale, bool isDark, int totalCount) {
    final allLabel = totalCount > 0
        ? '${AppTranslations.get('all', locale)} · $totalCount'
        : AppTranslations.get('all', locale);

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildChip(
            label: allLabel,
            isSelected: filters.type == 'all' && !filters.hasWomenPrayerArea && !filters.hasWuduWomen,
            isDark: isDark,
            onTap: () => ref.read(filtersProvider.notifier).resetFilters(),
          ),
          _buildChip(
            label: AppTranslations.get('masjid', locale),
            isSelected: filters.type == 'masjid',
            isDark: isDark,
            onTap: () => ref.read(filtersProvider.notifier).setType(
                  filters.type == 'masjid' ? 'all' : 'masjid',
                ),
          ),
          _buildChip(
            label: AppTranslations.get('musalla', locale),
            isSelected: filters.type == 'musalla',
            isDark: isDark,
            onTap: () => ref.read(filtersProvider.notifier).setType(
                  filters.type == 'musalla' ? 'all' : 'musalla',
                ),
          ),
          _buildChip(
            label: AppTranslations.get('women_friendly', locale),
            isSelected: filters.hasWomenPrayerArea || filters.hasWuduWomen,
            isDark: isDark,
            onTap: () {
              ref.read(filtersProvider.notifier).toggleWomenPrayer();
              ref.read(filtersProvider.notifier).toggleWuduWomen();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
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
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextSecondary),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String locale) {
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
            AppTranslations.get('no_mosques_found', locale),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppTranslations.get('location_disabled_msg', locale),
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
            label: Text(
              AppTranslations.get('refresh_search', locale),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
