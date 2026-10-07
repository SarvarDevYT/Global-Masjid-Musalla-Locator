import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../core/utils/launcher_utils.dart';

class NavigationDialog extends StatelessWidget {
  final double lat;
  final double lng;
  final String title;
  final String locale;

  const NavigationDialog({
    super.key,
    required this.lat,
    required this.lng,
    required this.title,
    required this.locale,
  });

  static void show(BuildContext context, {
    required double lat,
    required double lng,
    required String title,
    required String locale,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => NavigationDialog(
        lat: lat,
        lng: lng,
        title: title,
        locale: locale,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final options = [
      {'name': 'Google Maps', 'icon': Icons.map, 'app': NavigationApp.googleMaps, 'color': Colors.blue},
      {'name': 'Yandex Maps', 'icon': Icons.navigation, 'app': NavigationApp.yandexMaps, 'color': Colors.red},
      {'name': '2GIS', 'icon': Icons.explore, 'app': NavigationApp.twoGis, 'color': Colors.green},
      {'name': 'Apple Maps', 'icon': Icons.apple, 'app': NavigationApp.appleMaps, 'color': Colors.grey.shade700},
      {'name': 'Waze', 'icon': Icons.directions_car, 'app': NavigationApp.waze, 'color': Colors.cyan},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppTranslations.get('navigate_with', locale),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final opt = options[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (opt['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(opt['icon'] as IconData, color: opt['color'] as Color),
                ),
                title: Text(
                  opt['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  LauncherUtils.openNavigationApp(
                    app: opt['app'] as NavigationApp,
                    lat: lat,
                    lng: lng,
                    title: title,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
