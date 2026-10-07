import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
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

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (index) {
          ref.read(currentTabProvider.notifier).state = index;
        },
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        elevation: 10,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home, color: AppColors.primary),
            label: AppTranslations.get('all', locale) == 'Barchasi' ? 'Bosh Sahifa' : 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map, color: AppColors.primary),
            label: AppTranslations.get('all', locale) == 'Barchasi' ? 'Xarita' : 'Map',
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore, color: AppColors.accentGold),
            label: AppTranslations.get('qibla_compass', locale).split(' ').first,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings, color: AppColors.primary),
            label: AppTranslations.get('settings', locale),
          ),
        ],
      ),
    );
  }
}
