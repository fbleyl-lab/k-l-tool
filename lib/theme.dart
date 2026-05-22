import 'package:flutter/material.dart';

/// Helles, modernes Design im Apple/iOS-Stil.
class AppTheme {
  // iOS-Systemfarben
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosBackground = Color(0xFFF2F2F7); // System Grouped Background
  static const Color iosCard = Colors.white;
  static const Color iosLabel = Color(0xFF1C1C1E);
  static const Color iosSecondary = Color(0xFF8E8E93);
  static const Color iosGreen = Color(0xFF34C759);
  static const Color iosRed = Color(0xFFFF3B30);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: iosBlue,
        primary: iosBlue,
        brightness: Brightness.light,
        surface: iosBackground,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: iosBackground,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: iosBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: iosLabel,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: iosLabel,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: iosCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: iosBlue,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: iosCard,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: iosBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: iosSecondary),
        floatingLabelStyle: const TextStyle(color: iosBlue),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: iosBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: iosBlue,
        foregroundColor: Colors.white,
        elevation: 1,
        extendedTextStyle:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9))),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? iosGreen : const Color(0xFFE9E9EA)),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFD1D1D6),
        thickness: 0.5,
        space: 0.5,
      ),
    );
  }
}
