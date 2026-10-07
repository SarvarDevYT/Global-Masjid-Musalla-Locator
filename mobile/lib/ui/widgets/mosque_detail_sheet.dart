import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/mosque_model.dart';
import 'amenity_chip.dart';
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo or Gradient Banner
                  if (mosque.photoUrl != null && mosque.photoUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        mosque.photoUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackBanner(),
                      ),
                    )
                  else
                    _buildFallbackBanner(),

                  const SizedBox(height: 16),

                  // Type and distance tags
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: mosque.isMasjid
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          mosque.isMasjid
                              ? AppTranslations.get('masjid', locale)
                              : AppTranslations.get('musalla', locale),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: mosque.isMasjid ? AppColors.primary : AppColors.accentGold,
                          ),
                        ),
                      ),
                      if (mosque.distanceMeters != null)
                        Text(
                          '${AppTranslations.get('distance', locale)}: ${GeoUtils.formatDistance(mosque.distanceMeters!)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Name & Alt Name
                  Text(
                    mosque.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (mosque.altName != null && mosque.altName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      mosque.altName!,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Address
                  if (mosque.address.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            mosque.address,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Amenities Checklist
                  Text(
                    'Qulayliklar va Sharoitlar',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AmenityChip(
                        icon: Icons.water_drop,
                        label: AppTranslations.get('wudu_men', locale),
                        isAvailable: mosque.hasWuduMen,
                      ),
                      AmenityChip(
                        icon: Icons.shower,
                        label: AppTranslations.get('wudu_women', locale),
                        isAvailable: mosque.hasWuduWomen,
                      ),
                      AmenityChip(
                        icon: Icons.female,
                        label: AppTranslations.get('women_section', locale),
                        isAvailable: mosque.hasWomenPrayerArea,
                      ),
                      AmenityChip(
                        icon: Icons.access_time_filled,
                        label: AppTranslations.get('juma_prayer', locale),
                        isAvailable: mosque.hasJuma,
                      ),
                      AmenityChip(
                        icon: Icons.accessible,
                        label: AppTranslations.get('wheelchair_access', locale),
                        isAvailable: mosque.hasWheelchairAccess,
                      ),
                      AmenityChip(
                        icon: Icons.local_parking,
                        label: AppTranslations.get('parking', locale),
                        isAvailable: mosque.hasParking,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Large Navigate Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
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

                  // Report Issue button
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

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: AppColors.emeraldGradient,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Islamic crescent / aura circle
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.5),
            ),
          ),
          Icon(
            mosque.isMasjid ? Icons.mosque : Icons.meeting_room,
            size: 50,
            color: AppColors.goldLight,
          ),
        ],
      ),
    );
  }
}
