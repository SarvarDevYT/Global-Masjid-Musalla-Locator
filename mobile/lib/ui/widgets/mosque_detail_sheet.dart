import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/mosque_model.dart';
import 'navigation_dialog.dart';
import 'report_dialog.dart';

class MosqueDetailSheet extends StatelessWidget {
  final MosqueModel mosque;
  final String locale;
  final Future<bool> Function(String mosqueId, String reason, String details) onReportSubmit;

  const MosqueDetailSheet({
    super.key,
    required this.mosque,
    required this.locale,
    required this.onReportSubmit,
  });

  static void show(
    BuildContext context, {
    required MosqueModel mosque,
    required String locale,
    required Future<bool> Function(String mosqueId, String reason, String details) onReportSubmit,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MosqueDetailSheet(
        mosque: mosque,
        locale: locale,
        onReportSubmit: onReportSubmit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    final distText = mosque.distanceMeters != null
        ? GeoUtils.formatDistance(mosque.distanceMeters!)
        : '---';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Photo (16:9) or Elegant Islamic Banner
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: mosque.photoUrl != null && mosque.photoUrl!.isNotEmpty
                        ? AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              mosque.photoUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackBanner(isDark),
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _buildFallbackBanner(isDark),
                          ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Badges: Type and "Tasdiqlangan"
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: mosque.isMasjid
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: mosque.isMasjid
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : AppColors.gold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          mosque.isMasjid
                              ? AppTranslations.get('masjid', locale)
                              : AppTranslations.get('musalla', locale),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: mosque.isMasjid ? AppColors.primary : AppColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF059669).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text(
                              AppTranslations.get('verified', locale),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 3. Mosque Name
                  Text(
                    mosque.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),

                  // Full Address
                  if (mosque.address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            mosque.address,
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),

                  // 4. Stats Row (2 Cards: Distance & Confirmed count)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0E272C) : const Color(0xFFF3F9F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                distText,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppTranslations.get('distance', locale),
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0E272C) : const Color(0xFFF3F9F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${mosque.verifiedCount}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppTranslations.get('confirmed_by_users', locale),
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 5. Qulayliklar (Amenities - Distinction between available and unavailable)
                  Text(
                    AppTranslations.get('amenities', locale),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3.2,
                    children: [
                      // Tahoratxona
                      _buildAmenityGridItem(
                        icon: Icons.water_drop_outlined,
                        label: AppTranslations.get('wudu_men', locale),
                        isAvailable: mosque.hasWuduMen,
                        isDark: isDark,
                      ),
                      // Juma namozi
                      _buildAmenityGridItem(
                        icon: Icons.access_time,
                        label: AppTranslations.get('juma_prayer', locale),
                        isAvailable: mosque.hasJuma,
                        isDark: isDark,
                      ),
                      // Avtoturargoh
                      _buildAmenityGridItem(
                        icon: Icons.local_parking,
                        label: AppTranslations.get('parking', locale),
                        isAvailable: mosque.hasParking,
                        isDark: isDark,
                      ),
                      // Ayollar tahoratxonasi
                      _buildAmenityGridItem(
                        icon: Icons.shower_outlined,
                        label: AppTranslations.get('wudu_women', locale),
                        isAvailable: mosque.hasWuduWomen,
                        isDark: isDark,
                      ),
                      // Ayollar zali
                      _buildAmenityGridItem(
                        icon: Icons.female,
                        label: AppTranslations.get('women_section', locale),
                        isAvailable: mosque.hasWomenPrayerArea,
                        isDark: isDark,
                      ),
                      // Nogironlar uchun kirish
                      _buildAmenityGridItem(
                        icon: Icons.accessible,
                        label: AppTranslations.get('wheelchair_access', locale),
                        isAvailable: mosque.hasWheelchairAccess,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 6. Large "Yo'nalish olish" Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      icon: const Icon(Icons.navigation, size: 20),
                      label: Text(
                        AppTranslations.get('navigate', locale),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Report Issue TextButton
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        ReportDialog.show(
                          context,
                          mosqueId: mosque.id,
                          mosqueName: mosque.name,
                          locale: locale,
                          onSubmit: onReportSubmit,
                        );
                      },
                      icon: const Icon(Icons.flag_outlined, size: 16, color: Colors.grey),
                      label: Text(
                        AppTranslations.get('report_issue', locale),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityGridItem({
    required IconData icon,
    required String label,
    required bool isAvailable,
    required bool isDark,
  }) {
    if (isAvailable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primaryDark.withValues(alpha: 0.3)
              : AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? AppColors.primaryLight.withValues(alpha: 0.25)
                : AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              size: 16,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            const Text(
              '—',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFallbackBanner(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.emeraldGradient,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
            ),
          ),
          Icon(
            mosque.isMasjid ? Icons.mosque : Icons.meeting_room,
            size: 48,
            color: AppColors.goldLight,
          ),
        ],
      ),
    );
  }
}
