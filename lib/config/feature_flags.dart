/// Compile-time feature flags controlled with `--dart-define`.
///
/// Example:
/// `flutter run --dart-define=ENABLE_UPLOAD_BILL=false`
abstract final class FeatureFlags {
  static const bool enableUploadBill =
      bool.fromEnvironment('ENABLE_UPLOAD_BILL', defaultValue: true);
}
