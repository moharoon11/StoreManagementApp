import 'package:flutter/material.dart';

/// Shared responsive breakpoints and dynamic-layout helpers so every screen
/// adapts consistently across phones, tablets and desktop — no fixed pixel
/// assumptions that can overflow on small screens.
abstract final class Ui {
  /// Phones (portrait).
  static const double compactMax = 600;

  /// Tablets / small desktop windows.
  static const double mediumMax = 1024;

  /// Large desktop windows.
  static const double largeMax = 1440;

  /// Maximum content width on very wide windows so layouts stay readable.
  static const double maxContentWidth = 1180;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactMax;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compactMax && width < mediumMax;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mediumMax;

  /// Page padding that scales with available width.
  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return const EdgeInsets.all(10);
    if (width < compactMax) return const EdgeInsets.all(12);
    if (width < mediumMax) return const EdgeInsets.all(16);
    return const EdgeInsets.all(24);
  }

  /// Heading size that scales with available width.
  static double headingSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 17;
    if (width < compactMax) return 19;
    if (width < mediumMax) return 21;
    return 24;
  }

  /// How many columns a grid should use for the given width, given a
  /// minimum tile width. Guarantees at least [minColumns] and never
  /// overflows: the grid itself stays fluid.
  static int columnsForWidth(double width, double minTileWidth,
      {int minColumns = 1, int? maxColumns}) {
    var cols = (width / minTileWidth).floor();
    if (cols < minColumns) cols = minColumns;
    if (maxColumns != null && cols > maxColumns) cols = maxColumns;
    return cols;
  }

  /// Context variant of [columnsForWidth] that subtracts page padding.
  static int gridColumns(BuildContext context, double minTileWidth,
      {int minColumns = 1, int? maxColumns}) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = pagePadding(context);
    final available = (width - padding.horizontal).clamp(200.0, maxContentWidth);
    return columnsForWidth(available, minTileWidth,
        minColumns: minColumns, maxColumns: maxColumns);
  }

  /// Constrained content wrapper: centres children and clamps the width so
  /// ultra-wide windows never stretch rows into unreadable lines.
  static Widget constrain(Widget child, {double maxWidth = maxContentWidth}) =>
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );

  /// Vertical gap that shrinks on very narrow phones to avoid overflow.
  static double gap(BuildContext context, [double normal = 14]) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return normal * .7;
    if (width < compactMax) return normal * .85;
    return normal;
  }
}
