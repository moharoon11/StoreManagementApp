import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';

/// Visual foundation for the app. Views can keep their functional widgets while
/// sharing a single polished, accessible SaaS language.
abstract final class AppColors {
  static const ink = Color(0xFF172033);
  static const canvas = Color(0xFFF6F7FB);
  static const brand = Color(0xFF365FF4);
  static const brandSoft = Color(0xFFEEF0FF);
  static const teal = Color(0xFF12A594);
  static const line = Color(0xFFE6E8EF);
  static const muted = Color(0xFF6C7486);
}

abstract final class AppTheme {
  static ThemeData forOption(AppThemeOption option) => switch (option) {
        AppThemeOption.light => _build(
            const ColorScheme.light(
              primary: AppColors.brand,
              secondary: AppColors.teal,
              surface: Colors.white,
              error: Color(0xFFE75C5C),
              onPrimary: Colors.white,
              onSurface: AppColors.ink,
              outline: AppColors.line,
              outlineVariant: AppColors.line,
            ),
            AppColors.canvas),
        AppThemeOption.nightOwl => _build(
            const ColorScheme.dark(
              primary: Color(0xFF82AAFF),
              secondary: Color(0xFFC3E88D),
              surface: Color(0xFF1D2A3A),
              error: Color(0xFFFF8A80),
              onPrimary: Color(0xFF0B1726),
              onSurface: Color(0xFFD6DEEB),
              outline: Color(0xFF34455B),
              outlineVariant: Color(0xFF34455B),
            ),
            const Color(0xFF011627)),
        AppThemeOption.evergreen => _build(
            const ColorScheme.light(
              primary: Color(0xFF256B5C),
              secondary: Color(0xFFB8751A),
              surface: Color(0xFFFFFFFF),
              error: Color(0xFFB33A3A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF17352F),
              outline: Color(0xFFDDE8E4),
              outlineVariant: Color(0xFFDDE8E4),
            ),
            const Color(0xFFF3F8F5)),
      };

  static ThemeData _build(ColorScheme colorScheme, Color canvas) {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).apply(
        bodyColor: colorScheme.onSurface, displayColor: colorScheme.onSurface);

    final radius = BorderRadius.circular(16);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      scaffoldBackgroundColor: canvas,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        labelStyle:
            TextStyle(color: colorScheme.onSurface.withValues(alpha: .66)),
        hintStyle:
            TextStyle(color: colorScheme.onSurface.withValues(alpha: .55)),
        prefixIconColor: colorScheme.onSurface.withValues(alpha: .66),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dividerTheme:
          DividerThemeData(color: colorScheme.outlineVariant, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
