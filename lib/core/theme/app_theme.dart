import 'package:flutter/material.dart';

/// Soft pastel theme for Uangku.
///
/// Palette:
/// - primary   : lavender  `#B6A6E9`
/// - secondary : mint      `#A8D8B9`
/// - tertiary  : blush     `#F5B7B1`
/// - surface   : cream     `#FFF9F3`
/// - error     : coral     `#E57373`
class AppTheme {
  static const Color _lavender = Color(0xFFB6A6E9);
  static const Color _lavenderContainer = Color(0xFFEBDDF4);
  static const Color _mint = Color(0xFFA8D8B9);
  static const Color _mintContainer = Color(0xFFD6EFDF);
  static const Color _blush = Color(0xFFF5B7B1);
  static const Color _blushContainer = Color(0xFFFCE4E1);
  static const Color _cream = Color(0xFFFFF9F3);
  static const Color _surfaceAlt = Color(0xFFFDF3EA);
  static const Color _outline = Color(0xFFE6DED3);
  static const Color _ink = Color(0xFF3B3A47);
  static const Color _inkMuted = Color(0xFF6E6B7B);
  static const Color _coral = Color(0xFFE57373);

  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: _lavender,
      onPrimary: Colors.white,
      primaryContainer: _lavenderContainer,
      onPrimaryContainer: _ink,
      secondary: _mint,
      onSecondary: _ink,
      secondaryContainer: _mintContainer,
      onSecondaryContainer: _ink,
      tertiary: _blush,
      onTertiary: _ink,
      tertiaryContainer: _blushContainer,
      onTertiaryContainer: _ink,
      error: _coral,
      onError: Colors.white,
      surface: _cream,
      onSurface: _ink,
      surfaceContainerHighest: _surfaceAlt,
      onSurfaceVariant: _inkMuted,
      outline: _outline,
      outlineVariant: Color(0xFFF0E7DA),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _cream,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _cream,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lavender,
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
          backgroundColor: _lavender,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _lavender),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _lavender,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lavenderContainer,
        selectedColor: _lavender,
        labelStyle: const TextStyle(color: _ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: _lavender, width: 1.5),
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
      primary: _lavender,
      onPrimary: Color(0xFF201A2E),
      primaryContainer: Color(0xFF4A3F6B),
      onPrimaryContainer: _lavenderContainer,
      secondary: _mint,
      onSecondary: Color(0xFF10251A),
      secondaryContainer: Color(0xFF2E5741),
      onSecondaryContainer: _mintContainer,
      tertiary: _blush,
      onTertiary: Color(0xFF3B1E1B),
      tertiaryContainer: Color(0xFF6B3A36),
      onTertiaryContainer: _blushContainer,
      error: _coral,
      onError: Colors.white,
      surface: Color(0xFF1E1B26),
      onSurface: Color(0xFFEDE7F0),
      surfaceContainerHighest: Color(0xFF2A2632),
      onSurfaceVariant: Color(0xFFBDB6C6),
      outline: Color(0xFF3D3947),
      outlineVariant: Color(0xFF2A2632),
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
