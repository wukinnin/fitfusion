import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Static color constants for use in Flame components (which cannot use ThemeData)
  static const Color gold = Color(0xFFFFD700);
  static const Color royalBlue = Color(0xFF1A237E);
  static const Color midnightNavy = Color(0xFF0D1B3E);
  static const Color crimson = Color(0xFFB71C1C);
  static const Color emerald = Color(0xFF2E7D32);
  static const Color parchment = Color(0xFFFFF8E1);
  static const Color brightGold = Color(0xFFFFEE58);
  static const Color creamWhite = Color(0xFFFFFDE7);

  static const Color _surface = Color(0xFF1A2D5A);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: royalBlue,
        secondary: gold,
        surface: _surface,
        error: crimson,
        onPrimary: creamWhite,
        onSecondary: midnightNavy,
        onSurface: creamWhite,
        onError: creamWhite,
      ),
      scaffoldBackgroundColor: midnightNavy,
      textTheme: GoogleFonts.cinzelTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: creamWhite),
          displayMedium: TextStyle(color: creamWhite),
          displaySmall: TextStyle(color: creamWhite),
          headlineLarge: TextStyle(color: creamWhite),
          headlineMedium: TextStyle(color: creamWhite),
          headlineSmall: TextStyle(color: creamWhite),
          titleLarge: TextStyle(color: creamWhite),
          titleMedium: TextStyle(color: creamWhite),
          titleSmall: TextStyle(color: creamWhite),
          bodyLarge: TextStyle(color: creamWhite),
          bodyMedium: TextStyle(color: creamWhite),
          bodySmall: TextStyle(color: creamWhite),
          labelLarge: TextStyle(color: creamWhite),
          labelMedium: TextStyle(color: creamWhite),
          labelSmall: TextStyle(color: creamWhite),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: royalBlue,
        foregroundColor: creamWhite,
        titleTextStyle: GoogleFonts.cinzelDecorative(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: gold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalBlue,
          foregroundColor: gold,
          textStyle: GoogleFonts.cinzel(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: gold, width: 2),
          ),
        ),
      ),
    );
  }
}
