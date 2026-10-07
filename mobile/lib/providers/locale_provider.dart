import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<String> {
  static const String _key = 'user_locale';

  LocaleNotifier() : super('uz') {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && ['uz', 'en', 'ru', 'ar', 'tr'].contains(saved)) {
      state = saved;
    }
  }

  Future<void> setLocale(String langCode) async {
    if (['uz', 'en', 'ru', 'ar', 'tr'].contains(langCode)) {
      state = langCode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, langCode);
    }
  }
}
