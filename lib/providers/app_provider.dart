import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../config/api_config.dart';
import '../utils/quantity_utils.dart';

enum AppThemeOption { light, nightOwl, evergreen }

class AppProvider extends ChangeNotifier {
  bool _isBootstrapping = true;
  bool get isBootstrapping => _isBootstrapping;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String _username = '';
  String get username => _username;

  int _selectedNavIndex = 0;
  int get selectedNavIndex => _selectedNavIndex;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AppThemeOption _themeOption = AppThemeOption.light;
  AppThemeOption get themeOption => _themeOption;

  // Cart State for Billing / POS
  final Map<int, Map<String, dynamic>> _cartItems =
      {}; // productId -> {product, quantity}
  Map<int, Map<String, dynamic>> get cartItems => _cartItems;

  double get cartTotal {
    double total = 0.0;
    _cartItems.forEach((key, item) {
      final price = (item['product']['sellingPrice'] as num).toDouble();
      final qty = quantityValue(item['quantity']);
      total += price * qty;
    });
    return total;
  }

  double get cartCount {
    double count = 0;
    _cartItems.forEach((key, item) {
      count += quantityValue(item['quantity']);
    });
    return count;
  }

  AppProvider() {
    checkAuth();
    ApiService.onUnauthorized = () {
      logout();
    };
  }

  Future<void> checkAuth() async {
    final minimumSplash =
        Future<void>.delayed(const Duration(milliseconds: 1300));
    try {
      final savedTheme = await StorageService.getTheme();
      _themeOption = AppThemeOption.values.firstWhere(
        (option) => option.name == savedTheme,
        orElse: () => AppThemeOption.light,
      );
      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        _isAuthenticated = true;
        _username = (await StorageService.getUsername()) ?? '';
      } else {
        _isAuthenticated = false;
      }
    } catch (_) {
      _isAuthenticated = false;
    } finally {
      await minimumSplash;
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  void setNavIndex(int index) {
    _selectedNavIndex = index;
    notifyListeners();
  }

  Future<void> setThemeOption(AppThemeOption option) async {
    if (_themeOption == option) return;
    _themeOption = option;
    notifyListeners();
    await StorageService.saveTheme(option.name);
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(ApiConfig.login, {
        'username': username,
        'password': password,
      });

      if (response['success'] == true) {
        final data = response['data'];
        await StorageService.saveAuthData(
          token: data['token'],
          username: data['username'],
          userId: data['userId'],
        );
        _isAuthenticated = true;
        _username = data['username'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'];
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(ApiConfig.register, {
        'username': username,
        'password': password,
      });

      if (response['success'] == true) {
        final data = response['data'];
        await StorageService.saveAuthData(
          token: data['token'],
          username: data['username'],
          userId: data['userId'],
        );
        _isAuthenticated = true;
        _username = data['username'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'];
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await StorageService.clearAuthData();
    _isAuthenticated = false;
    _username = '';
    _cartItems.clear();
    _selectedNavIndex = 0;
    notifyListeners();
  }

  // Cart operations
  void addToCart(Map<String, dynamic> product) {
    final id = product['id'] as int;
    final availableStock = quantityValue(product['stockQuantity']);

    if (_cartItems.containsKey(id)) {
      final currentQty = quantityValue(_cartItems[id]!['quantity']);
      if (currentQty + 1 <= availableStock) {
        _cartItems[id]!['quantity'] = currentQty + 1;
      }
    } else {
      if (availableStock > 0) {
        _cartItems[id] = {
          'product': product,
          'quantity': availableStock < 1 ? availableStock : 1.0,
        };
      }
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    if (_cartItems.containsKey(productId)) {
      final currentQty = quantityValue(_cartItems[productId]!['quantity']);
      if (currentQty > 1) {
        _cartItems[productId]!['quantity'] = currentQty - 1;
      } else {
        _cartItems.remove(productId);
      }
    }
    notifyListeners();
  }

  /// Sets an exact quantity so weighed and measured products can be sold in
  /// fractional amounts (for example, 1.5 KG).
  void setCartQuantity(int productId, double quantity) {
    final item = _cartItems[productId];
    if (item == null) return;

    final availableStock = quantityValue(item['product']['stockQuantity']);
    if (quantity <= 0) {
      _cartItems.remove(productId);
    } else if (quantity <= availableStock) {
      item['quantity'] = quantity;
    }
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }
}
