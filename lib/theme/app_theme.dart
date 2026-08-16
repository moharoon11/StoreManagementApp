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
              primary: Color(0xFF8B9CFF),
              secondary: Color(0xFF5EEAD4),
              surface: Color(0xFF151D31),
              error: Color(0xFFFF8A80),
              onPrimary: Color(0xFF0B1020),
              onSurface: Color(0xFFE7ECF5),
              outline: Color(0xFF2B3852),
              outlineVariant: Color(0xFF2B3852),
            ),
            const Color(0xFF0B1020)),
        AppThemeOption.evergreen => _build(
            const ColorScheme.light(
              primary: Color(0xFF9A4E25),
              secondary: Color(0xFF20756C),
              surface: Color(0xFFFFFDFC),
              error: Color(0xFFB33A3A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF332017),
              outline: Color(0xFFE9DCD1),
              outlineVariant: Color(0xFFE9DCD1),
            ),
            const Color(0xFFFFF7F0)),
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
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primary.withValues(alpha: .14),
          labelTextStyle: WidgetStatePropertyAll(
              TextStyle(color: colorScheme.onSurface, fontSize: 11))),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: colorScheme.surface,
          modalBackgroundColor: colorScheme.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
      popupMenuTheme: PopupMenuThemeData(
          color: colorScheme.surface,
          textStyle: TextStyle(color: colorScheme.onSurface)),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
