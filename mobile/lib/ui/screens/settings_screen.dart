import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    final languages = [
      {'code': 'uz', 'name': 'O\'zbekcha', 'flag': '🇺🇿'},
      {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
      {'code': 'ru', 'name': 'Русский', 'flag': '🇷🇺'},
      {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
      {'code': 'tr', 'name': 'Türkçe', 'flag': '🇹🇷'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get('settings', currentLocale)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Appearance
          _buildSectionHeader(AppTranslations.get('theme', currentLocale)),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Tizim sozlamalari (Avto)'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (val) => ref.read(themeModeProvider.notifier).setTheme(val!),
                ),
                RadioListTile<ThemeMode>(
                  title: Text(AppTranslations.get('light_mode', currentLocale)),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (val) => ref.read(themeModeProvider.notifier).setTheme(val!),
                ),
                RadioListTile<ThemeMode>(
                  title: Text(AppTranslations.get('dark_mode', currentLocale)),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (val) => ref.read(themeModeProvider.notifier).setTheme(val!),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Language
          _buildSectionHeader(AppTranslations.get('language', currentLocale)),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: languages.map((lang) {
                final isSelected = currentLocale == lang['code'];
                return ListTile(
                  leading: Text(lang['flag']!, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    lang['name']!,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () {
                    ref.read(localeProvider.notifier).setLocale(lang['code']!);
                  },
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Section: Offline Cache
          _buildSectionHeader('Offline Kesh & Ma\'lumotlar'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.cloud_done, color: AppColors.primary),
              title: const Text('Lokal Saqlangan Masjidlar'),
              subtitle: const Text('15-30 km radiusdagi masjidlar oflayn rejimda ishlaydi'),
              trailing: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kesh yangilandi')),
                  );
                },
                child: const Text('Tozalash'),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // About App
          Center(
            child: Column(
              children: [
                const Icon(Icons.mosque, size: 40, color: AppColors.primary),
                const SizedBox(height: 8),
                Text(
                  AppTranslations.get('app_title', currentLocale),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text('Versiya 1.0.0 • Global Edition', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey),
      ),
    );
  }
}
