import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/mosque_model.dart';
import 'amenity_chip.dart';
import 'navigation_dialog.dart';

class MosqueCard extends StatelessWidget {
  final MosqueModel mosque;
  final String locale;
  final VoidCallback onTap;

  const MosqueCard({
    super.key,
    required this.mosque,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.primary : Colors.black).withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Type & Distance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: mosque.isMasjid
                            ? AppColors.primary.withValues(alpha: 0.14)
                            : AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: mosque.isMasjid
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.gold.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            mosque.isMasjid ? Icons.mosque : Icons.meeting_room,
                            size: 14,
                            color: mosque.isMasjid ? AppColors.primaryLight : AppColors.gold,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            mosque.isMasjid
                                ? AppTranslations.get('masjid', locale)
                                : AppTranslations.get('musalla', locale),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: mosque.isMasjid ? (isDark ? AppColors.primaryLight : AppColors.primary) : AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mosque.distanceMeters != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.near_me, size: 12, color: isDark ? AppColors.goldLight : AppColors.goldDark),
                            const SizedBox(width: 4),
                            Text(
                              GeoUtils.formatDistance(mosque.distanceMeters!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.goldLight : AppColors.goldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Mosque Name
                Text(
                  mosque.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (mosque.address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          mosque.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Amenities badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (mosque.hasWuduMen)
                      AmenityChip(
                        icon: Icons.water_drop,
                        label: AppTranslations.get('wudu_men', locale),
                      ),
                    if (mosque.hasWuduWomen)
                      AmenityChip(
                        icon: Icons.shower,
                        label: AppTranslations.get('wudu_women', locale),
                      ),
                    if (mosque.hasWomenPrayerArea)
                      AmenityChip(
                        icon: Icons.female,
                        label: AppTranslations.get('women_section', locale),
                      ),
                    if (mosque.hasJuma)
                      AmenityChip(
                        icon: Icons.access_time_filled,
                        label: AppTranslations.get('juma_prayer', locale),
                      ),
                    if (mosque.hasWheelchairAccess)
                      AmenityChip(
                        icon: Icons.accessible,
                        label: AppTranslations.get('wheelchair_access', locale),
                      ),
                    if (mosque.hasParking)
                      AmenityChip(
                        icon: Icons.local_parking,
                        label: AppTranslations.get('parking', locale),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bottom row: Navigate Button
                SizedBox(
                  width: double.infinity,
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
                    icon: const Icon(Icons.directions, size: 18),
                    label: Text(AppTranslations.get('navigate', locale)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
