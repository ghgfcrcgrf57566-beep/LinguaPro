import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences. No account or cloud service is required.
class AppPreferences {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();
  static const _themeKey = 'linguapro_theme_mode_v1';
  static const _textScaleKey = 'linguapro_text_scale_v1';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  final ValueNotifier<double> textScale = ValueNotifier(1.0);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedTheme = prefs.getString(_themeKey);
    themeMode.value = switch (storedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    textScale.value = (prefs.getDouble(_textScaleKey) ?? 1.0).clamp(0.85, 1.3).toDouble();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode.value = value;
    final stored = switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, stored);
  }

  Future<void> setTextScale(double value) async {
    final safeValue = value.clamp(0.85, 1.3).toDouble();
    textScale.value = safeValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, safeValue);
  }
}
