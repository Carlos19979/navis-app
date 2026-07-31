import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyThemeMode = 'settings_theme_mode';
const _keyLocale = 'settings_locale';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden at startup',
  );
});

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(_keyThemeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  void set(ThemeMode mode) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_keyThemeMode, mode.name);
    state = mode;
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(_keyLocale);
    if (stored == null) return null;
    return Locale(stored);
  }

  void set(Locale? locale) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      prefs.remove(_keyLocale);
    } else {
      prefs.setString(_keyLocale, locale.languageCode);
    }
    state = locale;
  }
}
