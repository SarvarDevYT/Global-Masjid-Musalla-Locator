import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../providers/mosque_providers.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'qibla_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final locale = ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = const [
      DashboardScreen(),
      MapScreen(),
      QiblaScreen(),
      SettingsScreen(),
    ];

    String homeLabel = 'Bosh sahifa';
    String mapLabel = 'Xarita';
    String qiblaLabel = 'Qibla';
    String settingsLabel = 'Sozlamalar';

    if (locale == 'en') {
      homeLabel = 'Home';
      mapLabel = 'Map';
      qiblaLabel = 'Qibla';
      settingsLabel = 'Settings';
    } else if (locale == 'ru') {
      homeLabel = 'Главная';
      mapLabel = 'Карта';
      qiblaLabel = 'Кибла';
      settingsLabel = 'Настройки';
    } else if (locale == 'ar') {
      homeLabel = 'الرئيسية';
      mapLabel = 'الخريطة';
      qiblaLabel = 'القبلة';
      settingsLabel = 'الإعدادات';
    } else if (locale == 'tr') {
      homeLabel = 'Ana Sayfa';
      mapLabel = 'Harita';
      qiblaLabel = 'Kıble';
      settingsLabel = 'Ayarlar';
    }

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: currentTab,
          onDestinationSelected: (index) {
            ref.read(currentTabProvider.notifier).state = index;
          },
          backgroundColor: Colors.transparent,
          indicatorColor: currentTab == 2
              ? AppColors.gold.withValues(alpha: 0.22)
              : AppColors.primary.withValues(alpha: 0.16),
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.mosque, color: AppColors.primary),
              label: homeLabel,
            ),
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map, color: AppColors.primary),
              label: mapLabel,
            ),
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore, color: AppColors.gold),
              label: qiblaLabel,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings, color: AppColors.primary),
              label: settingsLabel,
            ),
          ],
        ),
      ),
    );
  }
}
