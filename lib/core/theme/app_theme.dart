import 'package:flutter/material.dart';

/// Airy Blue light theme for Uangku.
///
/// Palette:
/// - primary   : sky blue     `#4F8CFF`
/// - secondary : fresh green  `#38C6A0`
/// - tertiary  : warm amber   `#F59E0B`
/// - surface   : white        `#FFFFFF`
/// - scaffold  : cool mist    `#F7F9FC`
/// - error     : coral red    `#EF4444`
class AppTheme {
  static const Color _primary = Color(0xFF4F8CFF);
  static const Color _primaryContainer = Color(0xFFE1ECFF);
  static const Color _secondary = Color(0xFF38C6A0);
  static const Color _secondaryContainer = Color(0xFFD8F3E9);
  static const Color _tertiary = Color(0xFFF59E0B);
  static const Color _tertiaryContainer = Color(0xFFFEF1DC);
  static const Color _scaffold = Color(0xFFF7F9FC);
  static const Color _surface = Colors.white;
  static const Color _surfaceAlt = Color(0xFFEEF1F6);
  static const Color _outline = Color(0xFFE1E5EC);
  static const Color _outlineSoft = Color(0xFFF0F3F8);
  static const Color _ink = Color(0xFF111827);
  static const Color _inkMuted = Color(0xFF4B5563);
  static const Color _error = Color(0xFFEF4444);

  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: _primaryContainer,
      onPrimaryContainer: _ink,
      secondary: _secondary,
      onSecondary: Colors.white,
      secondaryContainer: _secondaryContainer,
      onSecondaryContainer: _ink,
      tertiary: _tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: _tertiaryContainer,
      onTertiaryContainer: _ink,
      error: _error,
      onError: Colors.white,
      surface: _surface,
      onSurface: _ink,
      surfaceContainerHighest: _surfaceAlt,
      onSurfaceVariant: _inkMuted,
      outline: _outline,
      outlineVariant: _outlineSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _scaffold,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _scaffold,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _primary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _primaryContainer,
        selectedColor: _primary,
        labelStyle: const TextStyle(color: _ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: _outline, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF7BAAFF),
      onPrimary: Color(0xFF0B1F3A),
      primaryContainer: Color(0xFF244480),
      onPrimaryContainer: _primaryContainer,
      secondary: Color(0xFF6FDDBB),
      onSecondary: Color(0xFF0B2E23),
      secondaryContainer: Color(0xFF1F5A46),
      onSecondaryContainer: _secondaryContainer,
      tertiary: Color(0xFFFFB84D),
      onTertiary: Color(0xFF3A2600),
      tertiaryContainer: Color(0xFF6B4300),
      onTertiaryContainer: _tertiaryContainer,
      error: Color(0xFFFF6B6B),
      onError: Colors.white,
      surface: Color(0xFF0F1420),
      onSurface: Color(0xFFE5E7EB),
      surfaceContainerHighest: Color(0xFF1A2130),
      onSurfaceVariant: Color(0xFF9CA3AF),
      outline: Color(0xFF2A3244),
      outlineVariant: Color(0xFF1A2130),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
