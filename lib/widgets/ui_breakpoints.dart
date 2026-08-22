import 'package:flutter/material.dart';

/// Shared responsive breakpoints and density helpers so every screen adapts
/// consistently across phones, tablets and desktop.
abstract final class Ui {
  /// Phones (portrait).
  static const double compactMax = 600;

  /// Tablets / small desktop windows.
  static const double mediumMax = 1024;

  /// Maximum content width on very wide windows so layouts stay readable.
  static const double maxContentWidth = 1280;

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
    if (width < compactMax) return const EdgeInsets.all(10);
    if (width < mediumMax) return const EdgeInsets.all(14);
    return const EdgeInsets.all(20);
  }

  /// Heading size that scales with available width.
  static double headingSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactMax) return 17;
    if (width < mediumMax) return 19;
    return 22;
  }
}