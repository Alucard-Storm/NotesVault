import 'package:flutter/material.dart';

/// App-wide theme constants and configuration
class AppTheme {
  // Colors
  static const Color seedColor = Color(0xFF7C6EF5);
  static const Color lightScaffoldBackground = Color(0xFFF5F4FB);
  static const Color lightCardColor = Colors.white;
  static const Color lightCardBorderColor = Color(0xFFECEBF3);

  // Border radius
  static const double cardBorderRadius = 16.0;

  /// Light theme configuration
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: lightScaffoldBackground,
      cardTheme: CardThemeData(
        color: lightCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          side: const BorderSide(color: lightCardBorderColor),
        ),
      ),
    );
  }

  /// Dark theme configuration
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
    );
  }
}
