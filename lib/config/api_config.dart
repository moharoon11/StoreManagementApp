import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Set this once at release build time to point the app to the hosted API.
  /// Example:
  /// flutter build apk --dart-define=API_BASE_URL=https://api.example.com/api
  ///
  /// It intentionally includes `/api`, because every endpoint below is
  /// relative to that API root. Leaving it blank retains local development
  /// addresses, so no code needs changing between environments.
  /// 
  static const API_URL = "http://easybilling.runasp.net/api";
  static const Local_URL = "http://localhost:5009/api";
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: API_URL);

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    }
    if (kIsWeb) {
      return API_URL;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // 127.0.0.1 works seamlessly with `adb reverse tcp:5009 tcp:5009` over USB
      return API_URL;
    } else {
      return API_URL;
    }
  }

  // Endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String storeProfile = '/store/profile';
  static const String categories = '/categories';
  static const String products = '/products';
  static const String favourites = '/favourites';
  static const String checkout = '/billing/checkout';
  static const String manualCheckout = '/billing/manual-checkout';
  static const String invoices = '/invoices';
  static const String stockMovements = '/stock/movements';
  static const String stockAdjust = '/stock/adjust';
  static const String salesReports = '/reports/sales';
  static const String dashboard = '/dashboard';
  static const String uploadImage = '/upload/image';
  static const String extractBill = '/inventory/extract-bill';
  static const String processBill = '/inventory/process-bill';
}
