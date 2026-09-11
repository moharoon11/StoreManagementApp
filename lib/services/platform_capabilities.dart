import 'package:flutter/foundation.dart';

/// Centralized platform checks so desktop and mobile behaviors stay aligned.
abstract final class PlatformCapabilities {
  static bool get supportsCameraCapture =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool get opensPdfInsteadOfShare => isDesktop;
}
