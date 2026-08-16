import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../config/api_config.dart';

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

  // Cart State for Billing / POS
  final Map<int, Map<String, dynamic>> _cartItems =
      {}; // productId -> {product, quantity}
  Map<int, Map<String, dynamic>> get cartItems => _cartItems;

  double get cartTotal {
    double total = 0.0;
    _cartItems.forEach((key, item) {
      final price = (item['product']['sellingPrice'] as num).toDouble();
      final qty = item['quantity'] as int;
      total += price * qty;
    });
    return total;
  }

  int get cartCount {
    int count = 0;
    _cartItems.forEach((key, item) {
      count += item['quantity'] as int;
    });
    return count;
  }

  AppProvider() {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final minimumSplash =
        Future<void>.delayed(const Duration(milliseconds: 1300));
    try {
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
    final availableStock = product['stockQuantity'] as int;

    if (_cartItems.containsKey(id)) {
      final currentQty = _cartItems[id]!['quantity'] as int;
      if (currentQty < availableStock) {
        _cartItems[id]!['quantity'] = currentQty + 1;
      }
    } else {
      if (availableStock > 0) {
        _cartItems[id] = {
          'product': product,
          'quantity': 1,
        };
      }
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    if (_cartItems.containsKey(productId)) {
      final currentQty = _cartItems[productId]!['quantity'] as int;
      if (currentQty > 1) {
        _cartItems[productId]!['quantity'] = currentQty - 1;
      } else {
        _cartItems.remove(productId);
      }
    }
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }
}
