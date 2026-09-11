import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/app_provider.dart';

/// Shared visual tokens for the redesigned workspace.
abstract final class AppColors {
  static const ink = Color(0xFF0B1728);
  static const canvas = Color(0xFFF1F5F9);
  static const surface = Color(0xFFFCFEFF);
  static const brand = Color(0xFF0F766E);
  static const brandDeep = Color(0xFF115E59);
  static const cobalt = Color(0xFF2563EB);
  static const aqua = Color(0xFF06B6D4);
  static const sage = Color(0xFF2F855A);
  static const clay = Color(0xFF0EA5E9);
  static const line = Color(0xFFD5DFEA);
  static const muted = Color(0xFF5C6B7E);
  static const cream = Color(0xFFF7FAFC);
  static const fog = Color(0xFFE8F0F8);

  // Backward-compatible aliases used by a few existing screens.
  static const bronze = brand;
  static const bronzeDeep = brandDeep;
}

abstract final class AppTheme {
  static ThemeData forOption(AppThemeOption option) => switch (option) {
        AppThemeOption.light => _build(
            brightness: Brightness.light,
            seed: AppColors.brand,
            primary: AppColors.brand,
            onPrimary: Colors.white,
            secondary: AppColors.cobalt,
            tertiary: AppColors.aqua,
            canvas: AppColors.canvas,
            surface: AppColors.surface,
            onSurface: AppColors.ink,
            line: AppColors.line,
          ),
        AppThemeOption.nightOwl => _build(
            brightness: Brightness.dark,
            seed: const Color(0xFF38BDF8),
            primary: const Color(0xFF67E8F9),
            onPrimary: const Color(0xFF062033),
            secondary: const Color(0xFF60A5FA),
            tertiary: const Color(0xFF34D399),
            canvas: const Color(0xFF07111F),
            surface: const Color(0xFF0B1728),
            onSurface: const Color(0xFFF4F8FC),
            line: const Color(0xFF1F3147),
          ),
        AppThemeOption.evergreen => _build(
            brightness: Brightness.light,
            seed: const Color(0xFF1F6F5C),
            primary: const Color(0xFF1F6F5C),
            onPrimary: Colors.white,
            secondary: const Color(0xFF0F4C81),
            tertiary: const Color(0xFF2F855A),
            canvas: const Color(0xFFF3F7F4),
            surface: const Color(0xFFFFFEFB),
            onSurface: const Color(0xFF15261E),
            line: const Color(0xFFD3DED7),
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
      outlineVariant:
          _blend(line, onSurface, brightness == Brightness.dark ? .12 : .05),
      error: brightness == Brightness.dark
          ? const Color(0xFFFFA8A0)
          : const Color(0xFFB42318),
      shadow: Colors.black,
      surfaceTint: primary,
    );

    final base = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    TextStyle display(double size) => GoogleFonts.spaceGrotesk(
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1.04,
          letterSpacing: -.9,
          color: onSurface,
        );

    final textTheme = base.copyWith(
      displayLarge: display(60),
      displayMedium: display(50),
      displaySmall: display(42),
      headlineLarge: display(38),
      headlineMedium: display(32),
      headlineSmall: display(27),
      titleLarge: GoogleFonts.spaceGrotesk(
        color: onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.16,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        color: onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.28,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        color: onSurface,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        color: onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.55,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        color: onSurface,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        color: onSurface.withValues(alpha: .72),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.42,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        color: onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        color: onSurface,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        color: onSurface.withValues(alpha: .78),
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
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
        backgroundColor: _blend(
          surface,
          onSurface,
          brightness == Brightness.dark ? .16 : .06,
        ),
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _blend(
          surface,
          primary,
          brightness == Brightness.dark ? .08 : .035,
        ),
        labelStyle: textTheme.bodyMedium
            ?.copyWith(color: onSurface.withValues(alpha: .72)),
        hintStyle: textTheme.bodyMedium
            ?.copyWith(color: onSurface.withValues(alpha: .46)),
        prefixIconColor: onSurface.withValues(alpha: .62),
        suffixIconColor: onSurface.withValues(alpha: .62),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: .2),
        selectionHandleColor: primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        backgroundColor: _blend(
          surface,
          primary,
          brightness == Brightness.dark ? .05 : .02,
        ),
        selectedColor: primary.withValues(alpha: .14),
        secondarySelectedColor: primary.withValues(alpha: .14),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: textTheme.labelMedium!,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface.withValues(alpha: .72),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall
            ?.copyWith(color: onSurface.withValues(alpha: .62)),
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
        indicatorColor: primary.withValues(alpha: .11),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall!.copyWith(
            color: selected ? primary : onSurface.withValues(alpha: .72),
            letterSpacing: .3,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : onSurface.withValues(alpha: .72),
            size: 22,
          );
        }),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(999),
        thickness: WidgetStateProperty.all(8),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return primary.withValues(alpha: .9);
          }
          return primary.withValues(alpha: .42);
        }),
        trackColor: WidgetStateProperty.all(
          _blend(
            surface,
            primary,
            brightness == Brightness.dark ? .08 : .03,
          ),
        ),
      ),
    );
  }

  static Color _blend(Color a, Color b, double amount) =>
      Color.lerp(a, b, amount) ?? a;
}
