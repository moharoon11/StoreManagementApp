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

  /// Scales down every style that carries an explicit font size, keeping the
  /// type ramp compact. Styles without a fixed size are left untouched, which
  /// keeps [TextStyle.apply]'s assertions happy.
  static TextTheme _scaleDown(TextTheme theme, double factor) => TextTheme(
        displayLarge: _sized(theme.displayLarge, factor),
        displayMedium: _sized(theme.displayMedium, factor),
        displaySmall: _sized(theme.displaySmall, factor),
        headlineLarge: _sized(theme.headlineLarge, factor),
        headlineMedium: _sized(theme.headlineMedium, factor),
        headlineSmall: _sized(theme.headlineSmall, factor),
        titleLarge: _sized(theme.titleLarge, factor),
        titleMedium: _sized(theme.titleMedium, factor),
        titleSmall: _sized(theme.titleSmall, factor),
        bodyLarge: _sized(theme.bodyLarge, factor),
        bodyMedium: _sized(theme.bodyMedium, factor),
        bodySmall: _sized(theme.bodySmall, factor),
        labelLarge: _sized(theme.labelLarge, factor),
        labelMedium: _sized(theme.labelMedium, factor),
        labelSmall: _sized(theme.labelSmall, factor),
      );

  static TextStyle? _sized(TextStyle? style, double factor) {
    if (style == null) return null;
    final size = style.fontSize;
    return size == null ? style : style.copyWith(fontSize: size * factor);
  }

  static ThemeData _build(ColorScheme colorScheme, Color canvas) {
    // Slightly scaled-down type ramp keeps the whole app feeling compact on
    // every device size.
    final textTheme = _scaleDown(
      GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ).apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface),
      .94,
    );

    final radius = BorderRadius.circular(16);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
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
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 34),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primary.withValues(alpha: .14),
        labelStyle: TextStyle(color: colorScheme.onSurface, fontSize: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        iconColor: colorScheme.onSurface.withValues(alpha: .75),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme:
          DividerThemeData(color: colorScheme.outlineVariant, space: 1),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primary.withValues(alpha: .14),
          height: 60,
          labelTextStyle: WidgetStatePropertyAll(
              TextStyle(color: colorScheme.onSurface, fontSize: 10))),
      navigationRailTheme: NavigationRailThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: colorScheme.primary.withValues(alpha: .14),
          selectedIconTheme: IconThemeData(color: colorScheme.primary),
          unselectedIconTheme:
              IconThemeData(color: colorScheme.onSurface.withValues(alpha: .6)),
          selectedLabelTextStyle:
              TextStyle(color: colorScheme.primary, fontSize: 11),
          unselectedLabelTextStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: .6),
              fontSize: 11)),
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
