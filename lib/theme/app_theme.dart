import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';

/// "Ledger & Gold" — a restrained, professional design language.
/// Deep forest ink, warm paper canvas, brass accent. Deliberately the
/// opposite of the previous rounded blue SaaS look: sharper corners,
/// hairline dividers, flat headers, tabular numerals.
abstract final class AppColors {
  static const ink = Color(0xFF1B2430);
  static const inkSoft = Color(0xFF334155);
  static const canvas = Color(0xFFF3F1EA);
  static const brand = Color(0xFF134E3A);
  static const brandDeep = Color(0xFF0C3527);
  static const brandSoft = Color(0xFFE6EFE9);
  static const teal = Color(0xFFA9730A);
  static const gold = Color(0xFFB7791F);
  static const goldSoft = Color(0xFFF7ECD4);
  static const line = Color(0xFFE2DDCF);
  static const muted = Color(0xFF6E7683);
  static const danger = Color(0xFFB42318);
  static const success = Color(0xFF157347);
}

abstract final class AppTheme {
  static ThemeData forOption(AppThemeOption option) => switch (option) {
        AppThemeOption.light => _build(
            const ColorScheme.light(
              primary: AppColors.brand,
              onPrimary: Colors.white,
              secondary: AppColors.gold,
              onSecondary: Colors.white,
              tertiary: AppColors.brandDeep,
              surface: Colors.white,
              onSurface: AppColors.ink,
              surfaceContainerHighest: Color(0xFFEFEDE4),
              error: AppColors.danger,
              onError: Colors.white,
              outline: AppColors.line,
              outlineVariant: AppColors.line,
            ),
            AppColors.canvas),
        AppThemeOption.nightOwl => _build(
            const ColorScheme.dark(
              primary: Color(0xFF7BC9A3),
              onPrimary: Color(0xFF06231A),
              secondary: Color(0xFFE0B45C),
              onSecondary: Color(0xFF241703),
              tertiary: Color(0xFF9ADBB8),
              surface: Color(0xFF131B26),
              onSurface: Color(0xFFE8EAF0),
              surfaceContainerHighest: Color(0xFF1D2635),
              error: Color(0xFFF1998E),
              onError: Color(0xFF2A0B08),
              outline: Color(0xFF2C3748),
              outlineVariant: Color(0xFF2C3748),
            ),
            const Color(0xFF0B111B)),
        AppThemeOption.evergreen => _build(
            const ColorScheme.light(
              primary: Color(0xFF5B3B0A),
              onPrimary: Colors.white,
              secondary: Color(0xFF134E3A),
              onSecondary: Colors.white,
              tertiary: Color(0xFF7A4E0C),
              surface: Color(0xFFFFFDF6),
              onSurface: Color(0xFF2A2118),
              surfaceContainerHighest: Color(0xFFF1EAD8),
              error: Color(0xFF9C2A1E),
              onError: Colors.white,
              outline: Color(0xFFE4D9BE),
              outlineVariant: Color(0xFFE4D9BE),
            ),
            const Color(0xFFF6F0DF)),
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
    // Inter keeps the whole app feeling like a ledger: crisp, neutral,
    // tabular. Previously this was a rounded geometric sans.
    final textTheme = _scaleDown(
      GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface),
      .96,
    );

    final radius = BorderRadius.circular(10);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      brightness: colorScheme.brightness,
      scaffoldBackgroundColor: canvas,
      colorScheme: colorScheme,
      textTheme: textTheme,
      dividerColor: colorScheme.outlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
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
        fillColor: colorScheme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: .5)
            : const Color(0xFFF8F7F2),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        selectedColor: colorScheme.primary.withValues(alpha: .12),
        labelStyle: TextStyle(color: colorScheme.onSurface, fontSize: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: ListTileThemeData(
        dense: false,
        iconColor: colorScheme.onSurface.withValues(alpha: .7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme:
          DividerThemeData(color: colorScheme.outlineVariant, space: 1),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: colorScheme.surface,
          indicatorColor: Colors.transparent,
          height: 68,
          labelTextStyle: WidgetStatePropertyAll(
              TextStyle(color: colorScheme.onSurface, fontSize: 11))),
      navigationRailTheme: NavigationRailThemeData(
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primary.withValues(alpha: .12),
          selectedIconTheme: IconThemeData(color: colorScheme.primary),
          unselectedIconTheme:
              IconThemeData(color: colorScheme.onSurface.withValues(alpha: .55)),
          selectedLabelTextStyle:
              TextStyle(color: colorScheme.primary, fontSize: 12),
          unselectedLabelTextStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: .55),
              fontSize: 12)),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: colorScheme.surface,
          modalBackgroundColor: colorScheme.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)))),
      popupMenuTheme: PopupMenuThemeData(
          color: colorScheme.surface,
          textStyle: TextStyle(color: colorScheme.onSurface)),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
