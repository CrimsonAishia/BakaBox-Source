import 'package:flutter/material.dart';

/// 移动端主题配置
class MobileTheme {
  static const Color primaryColor = Color(0xFF0080FF);
  static const Color secondaryColor = Color(0xFF1976D2);
  
  static ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: const Color(0xFFF8FAFC),
      surfaceContainerHighest: const Color(0xFFF1F5F9),
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      foregroundColor: const Color(0xFF1F2937),
      titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
      bodyLarge: TextStyle(fontSize: 15, color: Color(0xFF374151)),
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF374151)),
      bodySmall: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Color(0xFF9CA3AF),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: const Color(0xFF42A5F5),
      surface: const Color(0xFF1E293B),
      onSurface: Colors.white,
      surfaceContainer: const Color(0xFF334155),
      surfaceContainerHighest: const Color(0xFF0F172A),
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
      bodyLarge: TextStyle(fontSize: 15, color: Color(0xFFE2E8F0)),
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFFE2E8F0)),
      bodySmall: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E293B),
      selectedItemColor: primaryColor,
      unselectedItemColor: Color(0xFF64748B),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
