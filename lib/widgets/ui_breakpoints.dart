import 'package:flutter/material.dart';

/// Shared responsive breakpoints and density helpers so every screen adapts
/// consistently across phones, tablets and desktop.
abstract final class Ui {
  /// Phones and narrow split-screen widths.
  static const double compactMax = 720;

  /// Tablets and laptop-sized windows.
  static const double mediumMax = 1180;

  /// Maximum content width on very wide windows so layouts stay readable.
  static const double maxContentWidth = 1120;

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
    if (width < 420) return const EdgeInsets.all(10);
    if (width < compactMax) return const EdgeInsets.all(12);
    if (width < mediumMax) return const EdgeInsets.all(16);
    return const EdgeInsets.all(20);
  }

  /// Heading size that scales with available width.
  static double headingSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 420) return 21;
    if (width < compactMax) return 24;
    if (width < mediumMax) return 27;
    return 30;
  }
}
