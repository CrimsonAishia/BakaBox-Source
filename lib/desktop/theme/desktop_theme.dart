import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 桌面端主题配置
class DesktopTheme {
  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = Color(0xFF1976D2);

  static ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: AppColors.slate50,
      surfaceContainerHighest: const Color(0xFFE9EEF8),
    ),
    useMaterial3: true,
    fontFamily: 'Microsoft YaHei',
    scaffoldBackgroundColor: const Color(0xFFE9EEF8),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      foregroundColor: AppColors.gray800,
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.gray800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.08),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.gray800,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.gray800,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.gray800,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.gray800,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.gray700),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.gray700),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.gray500),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: const Color(0xFF42A5F5),
      surface: AppColors.slate800,
      onSurface: Colors.white,
      surfaceContainer: AppColors.slate700,
      surfaceContainerHighest: AppColors.slate900,
      error: AppColors.red500,
      onError: Colors.white,
      errorContainer: const Color(0xFF7F1D1D),
      onErrorContainer: Colors.white,
      outline: AppColors.slate500,
      shadow: Colors.black,
    ),
    useMaterial3: true,
    fontFamily: 'Microsoft YaHei',
    scaffoldBackgroundColor: AppColors.slate900,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.slate800.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.slate800.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.slate200),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.slate200),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.slate300),
    ),
  );
}
