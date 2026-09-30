import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _ink = Color(0xFF17332E);
  static const _green = Color(0xFF176B5B);
  static const _canvas = Color(0xFFF4F7F4);

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
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: _canvas,
        foregroundColor: _ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFDCECE5),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFDCE5E0)),
        ),
      ),
    );
  }
}
