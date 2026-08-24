import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5009/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // 127.0.0.1 works seamlessly with `adb reverse tcp:5009 tcp:5009` over USB
      return 'http://127.0.0.1:5009/api';
    } else {
      return 'http://localhost:5009/api';
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
