import 'package:flutter/material.dart';

import 'senapath_design.dart';

abstract final class AppTheme {
  static ThemeData get light {
    const ink = SenapathColors.ink;
    const canvas = SenapathColors.canvas;
    const surface = SenapathColors.white;
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: SenapathColors.coral,
      onPrimary: SenapathColors.ink,
      secondary: SenapathColors.indigo,
      onSecondary: SenapathColors.white,
      error: const Color(0xFFB42318),
      onError: SenapathColors.white,
      surface: surface,
      onSurface: ink,
      tertiary: SenapathColors.sky,
      onTertiary: SenapathColors.ink,
      surfaceContainerHighest: const Color(0xFFF0EEE8),
      onSurfaceVariant: const Color(0xFF514D48),
      outline: ink,
      outlineVariant: const Color(0xFF89847D),
      shadow: SenapathColors.ink,
      scrim: Colors.black,
      inverseSurface: ink,
      onInverseSurface: surface,
      inversePrimary: SenapathColors.coral,
      surfaceTint: SenapathColors.sky,
      primaryContainer: const Color(0xFFFFDAD5),
      onPrimaryContainer: SenapathColors.ink,
      secondaryContainer: const Color(0xFFEADDFF),
      onSecondaryContainer: SenapathColors.indigo,
      tertiaryContainer: const Color(0xFFCCF2FF),
      onTertiaryContainer: const Color(0xFF003849),
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
    );
    final textTheme = Typography.material2021().black
        .apply(bodyColor: ink, displayColor: ink, fontFamily: 'Roboto')
        .copyWith(
          bodySmall: const TextStyle(fontSize: 13, height: 1.4),
          bodyMedium: const TextStyle(fontSize: 15, height: 1.45),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
          headlineLarge: const TextStyle(
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
          headlineMedium: const TextStyle(
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
          headlineSmall: const TextStyle(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.18,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleSmall: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          labelLarge: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.35,
          ),
        );
    final borderRadius = BorderRadius.circular(SenapathShape.medium);
    final outline = BorderSide(color: ink, width: SenapathShape.borderWidth);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: ink),
        shape: Border(bottom: outline),
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: SenapathColors.sky,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: ink,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: outline,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ink,
        textColor: ink,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        minVerticalPadding: 12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: outline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: BorderSide(color: ink.withValues(alpha: 0.7), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: const BorderSide(color: SenapathColors.sky, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: BorderSide(color: colorScheme.error, width: 3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: BorderSide(color: colorScheme.error, width: 3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: SenapathColors.ink,
          backgroundColor: SenapathColors.coral,
          disabledForegroundColor: ink.withValues(alpha: 0.45),
          disabledBackgroundColor: SenapathColors.coral.withValues(alpha: 0.35),
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: outline,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: ink, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SenapathColors.indigo,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: SenapathColors.coral,
        foregroundColor: SenapathColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: outline,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: outline,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: ink),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SenapathShape.large),
          ),
          side: outline,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          side: BorderSide(color: ink, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1.5,
        space: 24,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SenapathColors.coral,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? SenapathColors.ink : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SenapathColors.spring
              : null,
        ),
        trackOutlineColor: WidgetStatePropertyAll(ink),
      ),
    );
  }
}
