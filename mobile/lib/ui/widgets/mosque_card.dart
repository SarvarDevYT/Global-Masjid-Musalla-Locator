import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/mosque_model.dart';
import 'navigation_dialog.dart';

class MosqueCard extends StatelessWidget {
  final MosqueModel mosque;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback? onMapTap;

  const MosqueCard({
    super.key,
    required this.mosque,
    required this.locale,
    required this.onTap,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    final distText = mosque.distanceMeters != null
        ? GeoUtils.formatDistance(mosque.distanceMeters!)
        : (mosque.formattedDistance.isNotEmpty ? mosque.formattedDistance : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon, Title, Address & Distance
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: mosque.isMasjid ? AppColors.emeraldGradient : AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: mosque.isMasjid ? AppColors.gold : AppColors.goldLight,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (mosque.isMasjid ? AppColors.primary : AppColors.gold)
                                .withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        mosque.isMasjid ? Icons.mosque : Icons.meeting_room,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title & Address
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mosque.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            mosque.address.isNotEmpty
                                ? mosque.address
                                : (mosque.city ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Distance Tag
                    if (distText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          distText,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Amenities Tags Row (Linear icons/tags, no raw emojis)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (mosque.hasWuduMen)
                      _buildLinearTag(
                        icon: Icons.water_drop_outlined,
                        label: AppTranslations.get('wudu_men', locale),
                        isDark: isDark,
                      ),
                    if (mosque.hasWomenPrayerArea)
                      _buildLinearTag(
                        icon: Icons.female,
                        label: AppTranslations.get('women_section', locale),
                        isDark: isDark,
                      ),
                    if (mosque.hasJuma)
                      _buildLinearTag(
                        icon: Icons.access_time,
                        label: AppTranslations.get('juma_prayer', locale),
                        isDark: isDark,
                      ),
                    if (mosque.hasParking)
                      _buildLinearTag(
                        icon: Icons.local_parking,
                        label: AppTranslations.get('parking', locale),
                        isDark: isDark,
                      ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(height: 1, color: borderColor),
                const SizedBox(height: 10),

                // Action Buttons: "Yo'nalish" and "Xarita"
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 44, // >= 44px tap zone
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
                              lat: mosque.lat,
                              lng: mosque.lng,
                              title: mosque.name,
                              locale: locale,
                            );
                          },
                          icon: const Icon(Icons.navigation, size: 16),
                          label: Text(
                            AppTranslations.get('navigate_short', locale),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44, // >= 44px tap zone
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? AppColors.goldLight : AppColors.primary,
                            side: BorderSide(
                              color: isDark ? AppColors.gold.withValues(alpha: 0.5) : AppColors.primaryLight,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: onMapTap ?? onTap,
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: Text(
                            AppTranslations.get('map', locale),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinearTag({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
