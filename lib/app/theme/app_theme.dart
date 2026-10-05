import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _ink = Color(0xFF17332E);
  static const _green = Color(0xFF176B5B);
  static const _canvas = Color(0xFFF4F7F4);
  static const _darkCanvas = Color(0xFF101815);
  static const _darkSurface = Color(0xFF18221E);

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _green,
          brightness: Brightness.light,
        ).copyWith(
          primary: _green,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: _ink,
          secondary: const Color(0xFF486B59),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFDCECE5),
          onSecondaryContainer: const Color(0xFF17332E),
          outline: const Color(0xFF77877F),
        );

    return _base(
      colorScheme: colorScheme,
      canvas: _canvas,
      appBarBackground: _canvas,
      navigationBackground: Colors.white,
      navigationIndicator: const Color(0xFFDCECE5),
      cardBackground: Colors.white,
      cardBorder: const Color(0xFFDCE5E0),
    );
  }

  static ThemeData get dark {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF78C8A4),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF8AD7B4),
          onPrimary: const Color(0xFF073829),
          surface: _darkSurface,
          onSurface: const Color(0xFFE1E9E4),
          secondary: const Color(0xFFB5CCBE),
          onSecondary: const Color(0xFF20372C),
          secondaryContainer: const Color(0xFF29483A),
          onSecondaryContainer: const Color(0xFFD2EBDD),
          outline: const Color(0xFF899890),
        );

    return _base(
      colorScheme: colorScheme,
      canvas: _darkCanvas,
      appBarBackground: _darkCanvas,
      navigationBackground: _darkSurface,
      navigationIndicator: const Color(0xFF29483A),
      cardBackground: _darkSurface,
      cardBorder: const Color(0xFF35443C),
    );
  }

  static ThemeData _base({
    required ColorScheme colorScheme,
    required Color canvas,
    required Color appBarBackground,
    required Color navigationBackground,
    required Color navigationIndicator,
    required Color cardBackground,
    required Color cardBorder,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ).copyWith(
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navigationBackground,
        indicatorColor: navigationIndicator,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 24,
      ),
    );
  }
}
