import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

class AppSettingsState {
  final ThemeMode themeMode;
  final Locale locale;

  /// 开发者选项：解锁所有复习（跳过时间锁）。
  final bool unlockAllReviews;

  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.unlockAllReviews = false,
  });

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? unlockAllReviews,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      unlockAllReviews: unlockAllReviews ?? this.unlockAllReviews,
    );
  }
}

@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  @override
  AppSettingsState build() {
    _loadSettings();
    return const AppSettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeString = prefs.getString('theme_mode') ?? 'system';
    final themeMode = switch (themeModeString) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final localeString = prefs.getString('locale') ?? 'en';
    final locale = Locale(localeString);

    final unlockAllReviews = prefs.getBool('unlock_all_reviews') ?? false;

    state = state.copyWith(
      themeMode: themeMode,
      locale: locale,
      unlockAllReviews: unlockAllReviews,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);

    final prefs = await SharedPreferences.getInstance();
    final modeString = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString('theme_mode', modeString);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
  }

  /// 设置是否解锁所有复习（开发者选项）。
  Future<void> setUnlockAllReviews(bool value) async {
    state = state.copyWith(unlockAllReviews: value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('unlock_all_reviews', value);
  }
}
