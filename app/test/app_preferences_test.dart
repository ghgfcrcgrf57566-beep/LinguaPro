import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:english_learning_legal_academy/services/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppPreferences.instance.themeMode.value = ThemeMode.system;
    AppPreferences.instance.textScale.value = 1.0;
  });

  test('loads system defaults when no preferences have been saved', () async {
    await AppPreferences.instance.load();

    expect(AppPreferences.instance.themeMode.value, ThemeMode.system);
    expect(AppPreferences.instance.textScale.value, 1.0);
  });

  test('persists selected theme and accessible text scale', () async {
    await AppPreferences.instance.setThemeMode(ThemeMode.dark);
    await AppPreferences.instance.setTextScale(1.2);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('linguapro_theme_mode_v1'), 'dark');
    expect(prefs.getDouble('linguapro_text_scale_v1'), 1.2);
    expect(AppPreferences.instance.themeMode.value, ThemeMode.dark);
    expect(AppPreferences.instance.textScale.value, 1.2);
  });

  test('clamps text scale to supported accessible range', () async {
    await AppPreferences.instance.setTextScale(2.0);

    expect(AppPreferences.instance.textScale.value, 1.3);
  });
}
