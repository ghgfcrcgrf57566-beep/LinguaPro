import 'package:flutter/material.dart';

import '../features/home/learning_map_screen.dart';
import '../services/app_preferences.dart';

class AcademyApp extends StatelessWidget {
  const AcademyApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1D9B69),
      secondary: const Color(0xFFE9B95D),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF101522) : const Color(0xFFF7F8FC),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF171E2D) : Colors.white,
        foregroundColor: dark ? const Color(0xFFF1F4FC) : const Color(0xFF14213D),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF1A2232) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: dark ? const Color(0xFF2B3548) : const Color(0xFFE9EDF4)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferences = AppPreferences.instance;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: preferences.themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'LinguaPro | أكاديمية الإنجليزية',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: mode,
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: preferences.textScale,
          builder: (context, scale, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        home: const LearningMapScreen(),
      ),
    );
  }
}
