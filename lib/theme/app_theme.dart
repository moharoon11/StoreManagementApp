import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/app_provider.dart';

/// Shared visual tokens for the redesigned workspace.
abstract final class AppColors {
  static const ink = Color(0xFF1F2428);
  static const canvas = Color(0xFFF4EDE2);
  static const surface = Color(0xFFFBF6EE);
  static const bronze = Color(0xFF7A5A3A);
  static const brand = bronze;
  static const bronzeDeep = Color(0xFF5C432D);
  static const sage = Color(0xFF617564);
  static const clay = Color(0xFFAA6C4B);
  static const line = Color(0xFFD8C9B6);
  static const muted = Color(0xFF736C62);
  static const cream = Color(0xFFF1E7D8);
}

abstract final class AppTheme {
  static ThemeData forOption(AppThemeOption option) => switch (option) {
        AppThemeOption.light => _build(
            brightness: Brightness.light,
            seed: AppColors.bronze,
            primary: AppColors.bronze,
            onPrimary: Colors.white,
            secondary: AppColors.sage,
            tertiary: AppColors.clay,
            canvas: AppColors.canvas,
            surface: AppColors.surface,
            onSurface: AppColors.ink,
            line: AppColors.line,
          ),
        AppThemeOption.nightOwl => _build(
            brightness: Brightness.dark,
            seed: const Color(0xFF8B7355),
            primary: const Color(0xFFD9B687),
            onPrimary: const Color(0xFF1F2328),
            secondary: const Color(0xFF89A38D),
            tertiary: const Color(0xFFE39A72),
            canvas: const Color(0xFF14181D),
            surface: const Color(0xFF1E2328),
            onSurface: const Color(0xFFF6EFE6),
            line: const Color(0xFF353D45),
          ),
        AppThemeOption.evergreen => _build(
            brightness: Brightness.light,
            seed: const Color(0xFF556B5B),
            primary: const Color(0xFF556B5B),
            onPrimary: Colors.white,
            secondary: const Color(0xFF8F603D),
            tertiary: const Color(0xFFA9785B),
            canvas: const Color(0xFFF1F0E7),
            surface: const Color(0xFFFBFAF5),
            onSurface: const Color(0xFF21261F),
            line: const Color(0xFFD1D2C4),
          ),
      };

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color tertiary,
    required Color canvas,
    required Color surface,
    required Color onSurface,
    required Color line,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      tertiary: tertiary,
      surface: surface,
      onSurface: onSurface,
      outline: line,
      outlineVariant: _blend(line, onSurface, .08),
      error: brightness == Brightness.dark
          ? const Color(0xFFFFA697)
          : const Color(0xFFB85345),
      shadow: Colors.black,
      surfaceTint: primary,
    );

    final base = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    TextStyle display(double size) => GoogleFonts.cormorantGaramond(
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1.02,
          letterSpacing: -.8,
          color: onSurface,
        );

    final textTheme = base.copyWith(
      displayLarge: display(58),
      displayMedium: display(48),
      displaySmall: display(40),
      headlineLarge: display(36),
      headlineMedium: display(31),
      headlineSmall: display(27),
      titleLarge: GoogleFonts.manrope(
        color: onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleMedium: GoogleFonts.manrope(
        color: onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleSmall: GoogleFonts.manrope(
        color: onSurface,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: GoogleFonts.manrope(
        color: onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.manrope(
        color: onSurface,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: 1.48,
      ),
      bodySmall: GoogleFonts.manrope(
        color: onSurface.withValues(alpha: .72),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.42,
      ),
      labelLarge: GoogleFonts.manrope(
        color: onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: GoogleFonts.manrope(
        color: onSurface,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: GoogleFonts.manrope(
        color: onSurface.withValues(alpha: .78),
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _blend(surface, onSurface, .08),
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _blend(surface, primary, brightness == Brightness.dark ? .08 : .03),
        labelStyle:
            textTheme.bodyMedium?.copyWith(color: onSurface.withValues(alpha: .7)),
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: onSurface.withValues(alpha: .45)),
        prefixIconColor: onSurface.withValues(alpha: .66),
        suffixIconColor: onSurface.withValues(alpha: .66),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: outline,
        enabledBorder: outline,
        disabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: .22),
        selectionHandleColor: primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 34),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: .14),
        secondarySelectedColor: primary.withValues(alpha: .14),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: textTheme.labelMedium!,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface.withValues(alpha: .72),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle:
            textTheme.bodySmall?.copyWith(color: onSurface.withValues(alpha: .6)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: .14),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall!.copyWith(
            color: selected ? primary : onSurface.withValues(alpha: .72),
            letterSpacing: .2,
          );
        }),
      ),
    );
  }

  static Color _blend(Color a, Color b, double amount) =>
      Color.lerp(a, b, amount) ?? a;
}
