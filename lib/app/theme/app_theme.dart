import 'package:flutter/material.dart';

import 'senapath_design.dart';

abstract final class AppTheme {
  /// Menyusun tema gelap dengan palet biru malam dan menurunkan komponen dasar
  /// dari tema terang.
  static ThemeData get dark {
    const background = Color(0xFF071122);
    const surface = Color(0xFF10243A);
    const surfaceRaised = Color(0xFF18334F);
    const foreground = Color(0xFFF4F7FB);
    const accent = Color(0xFF7FC8FF);
    const outline = Color(0xFF42617E);
    final lightTheme = light;
    final darkColorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: background,
      secondary: const Color(0xFFDDF3FE),
      onSecondary: background,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      surface: surface,
      onSurface: foreground,
      tertiary: const Color(0xFF99D0EC),
      onTertiary: background,
      surfaceContainerHighest: surfaceRaised,
      onSurfaceVariant: const Color(0xFFD0DDE9),
      outline: accent,
      outlineVariant: outline,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: foreground,
      onInverseSurface: background,
      inversePrimary: SenapathColors.blue,
      surfaceTint: accent,
      primaryContainer: surfaceRaised,
      onPrimaryContainer: foreground,
      secondaryContainer: surfaceRaised,
      onSecondaryContainer: foreground,
      tertiaryContainer: surfaceRaised,
      onTertiaryContainer: foreground,
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
    );
    final darkTextTheme = lightTheme.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    );
    final border = BorderSide(color: outline);

    return lightTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: darkTextTheme,
      primaryTextTheme: lightTheme.primaryTextTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      appBarTheme: lightTheme.appBarTheme.copyWith(
        backgroundColor: background,
        foregroundColor: foreground,
        titleTextStyle: darkTextTheme.titleLarge?.copyWith(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        actionsIconTheme: const IconThemeData(color: accent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: surfaceRaised,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: foreground,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
      cardTheme: lightTheme.cardTheme.copyWith(
        color: surface,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SenapathShape.medium),
          side: border,
        ),
      ),
      listTileTheme: lightTheme.listTileTheme.copyWith(
        iconColor: accent,
        textColor: foreground,
      ),
      inputDecorationTheme: lightTheme.inputDecorationTheme.copyWith(
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: border,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: border,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: lightTheme.filledButtonTheme.style?.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? foreground.withValues(alpha: 0.45)
                : background,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? accent.withValues(alpha: 0.35)
                : accent,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: lightTheme.outlinedButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(foreground),
          side: WidgetStatePropertyAll(border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: lightTheme.textButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(accent),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: lightTheme.iconButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(foreground),
        ),
      ),
      floatingActionButtonTheme: lightTheme.floatingActionButtonTheme.copyWith(
        backgroundColor: accent,
        foregroundColor: background,
      ),
      dialogTheme: lightTheme.dialogTheme.copyWith(
        backgroundColor: surface,
        titleTextStyle: darkTextTheme.titleLarge?.copyWith(color: foreground),
        contentTextStyle: darkTextTheme.bodyMedium?.copyWith(color: foreground),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SenapathShape.medium),
          side: border,
        ),
      ),
      bottomSheetTheme: lightTheme.bottomSheetTheme.copyWith(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SenapathShape.large),
          ),
          side: border,
        ),
      ),
      snackBarTheme: lightTheme.snackBarTheme.copyWith(
        backgroundColor: surfaceRaised,
        contentTextStyle: TextStyle(color: foreground),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          side: border,
        ),
      ),
      dividerTheme: lightTheme.dividerTheme.copyWith(color: outline),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? background : foreground,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : surfaceRaised,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(outline),
      ),
      iconTheme: const IconThemeData(color: accent),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : null,
        ),
        checkColor: const WidgetStatePropertyAll(background),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(accent)),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceRaised,
          borderRadius: BorderRadius.circular(SenapathShape.small),
        ),
        textStyle: const TextStyle(color: foreground),
      ),
    );
  }

  /// Menyusun tema terang beserta skema warna, tipografi, dan gaya komponen
  /// bawaan aplikasi.
  static ThemeData get light {
    const ink = SenapathColors.ink;
    const canvas = SenapathColors.canvas;
    const surface = SenapathColors.white;
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: SenapathColors.blue,
      onPrimary: SenapathColors.ink,
      secondary: SenapathColors.navy,
      onSecondary: SenapathColors.white,
      error: const Color(0xFFB42318),
      onError: SenapathColors.white,
      surface: surface,
      onSurface: ink,
      tertiary: SenapathColors.accent,
      onTertiary: SenapathColors.ink,
      surfaceContainerHighest: SenapathColors.pale,
      onSurfaceVariant: SenapathColors.navy,
      outline: SenapathColors.accent,
      outlineVariant: const Color(0xFFB7D9EA),
      shadow: SenapathColors.ink,
      scrim: Colors.black,
      inverseSurface: ink,
      onInverseSurface: surface,
      inversePrimary: SenapathColors.accent,
      surfaceTint: SenapathColors.accent,
      primaryContainer: SenapathColors.pale,
      onPrimaryContainer: SenapathColors.ink,
      secondaryContainer: SenapathColors.pale,
      onSecondaryContainer: SenapathColors.navy,
      tertiaryContainer: SenapathColors.pale,
      onTertiaryContainer: SenapathColors.navy,
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
    final outline = BorderSide(
      color: colorScheme.outlineVariant,
      width: SenapathShape.borderWidth,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        shape: const Border(),
        actionsIconTheme: const IconThemeData(color: SenapathColors.navy),
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: SenapathColors.pale,
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
          side: BorderSide(color: colorScheme.outlineVariant),
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
        errorMaxLines: 3,
        helperMaxLines: 3,
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
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: const BorderSide(color: SenapathColors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SenapathShape.small),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: SenapathColors.white,
          backgroundColor: SenapathColors.blue,
          disabledForegroundColor: ink.withValues(alpha: 0.45),
          disabledBackgroundColor: SenapathColors.blue.withValues(alpha: 0.35),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SenapathColors.navy,
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
        backgroundColor: SenapathColors.blue,
        foregroundColor: SenapathColors.white,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: colorScheme.outlineVariant),
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
          side: BorderSide(color: colorScheme.outlineVariant),
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
        color: SenapathColors.blue,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? SenapathColors.ink : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SenapathColors.blue
              : null,
        ),
        trackOutlineColor: WidgetStatePropertyAll(ink),
      ),
    );
  }
}
