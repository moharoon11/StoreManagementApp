import 'package:flutter/material.dart';

/// Shared responsive breakpoints and density helpers so every screen adapts
/// consistently across phones, tablets and desktop.
abstract final class Ui {
  /// Phones and narrow split-screen widths.
  static const double compactMax = 760;

  /// Smaller handsets where every vertical pixel matters.
  static const double phoneMax = 420;

  /// Tablets and laptop-sized windows.
  static const double mediumMax = 1240;

  /// Maximum content width on very wide windows so layouts stay readable.
  static const double maxContentWidth = 1360;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactMax;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phoneMax;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compactMax && width < mediumMax;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mediumMax;

  /// Page padding that scales with available width.
  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < phoneMax) return const EdgeInsets.all(10);
    if (width < compactMax) return const EdgeInsets.all(14);
    if (width < mediumMax) return const EdgeInsets.all(18);
    return const EdgeInsets.all(24);
  }

  /// Heading size that scales with available width.
  static double headingSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < phoneMax) return 22;
    if (width < compactMax) return 28;
    if (width < mediumMax) return 32;
    return 36;
  }
}
