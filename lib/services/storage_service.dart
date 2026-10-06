import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'jwt_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyHasSecureAuth = 'has_secure_auth';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _keyUsername = 'username';
  static const String _keyUserId = 'user_id';
  static const String _keyTheme = 'app_theme';
  static const String _keyHasSeenWelcome = 'has_seen_welcome';
  static const String _keyFavouriteProductIds = 'favourite_product_ids';
  static const String _keyFavouriteSyncOperations = 'favourite_sync_operations';
  static const String _keyCategoryLayout = 'category_layout';

  static Future<void> saveAuthData(
      {required String token,
      required String refreshToken,
      required String username,
      required int userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: _keyToken, value: token);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
    await prefs.setBool(_keyHasSecureAuth, true);
    await prefs.setString(_keyUsername, username);
    await prefs.setInt(_keyUserId, userId);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyHasSecureAuth) != true) return null;
    return _secureStorage.read(key: _keyToken);
  }

  // JWT expiry is stored as seconds since Unix epoch in its `exp` claim.
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyHasSecureAuth) != true) return null;
    return _secureStorage.read(key: _keyRefreshToken);
  }

  static Future<void> updateTokens({
    required String token,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _keyToken, value: token);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  static Future<bool> isTokenExpired() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return true;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return true;

      final expirySeconds = int.tryParse(payload['exp']?.toString() ?? '');
      if (expirySeconds == null) return true;

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expirySeconds * 1000,
        isUtc: true,
      );
      return !expiresAt.isAfter(DateTime.now().toUtc());
    } catch (_) {
      return true;
    }
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  static Future<String?> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTheme);
  }

  static Future<void> saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, theme);
  }

  static Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenWelcome) ?? false;
  }

  static Future<void> saveHasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenWelcome, true);
  }

  /// Favourites are deliberately kept on this device.  They are keyed by the
  /// signed-in user so changing accounts does not leak one catalogue's stars
  /// into another account.
  static Future<Set<int>> getFavouriteProductIds() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await getUserId();
    final values = prefs
            .getStringList('${_keyFavouriteProductIds}_${userId ?? 'guest'}') ??
        const <String>[];
    return values.map(int.tryParse).whereType<int>().toSet();
  }

  static Future<void> saveFavouriteProductIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await getUserId();
    await prefs.setStringList(
      '${_keyFavouriteProductIds}_${userId ?? 'guest'}',
      ids.map((id) => id.toString()).toList(growable: false),
    );
  }

  /// Pending changes survive restarts so an offline favourite tap is sent to
  /// the server the next time this user opens the app.
  static Future<Map<int, bool>> getFavouriteSyncOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await getUserId();
    final values = prefs.getStringList(
          '${_keyFavouriteSyncOperations}_${userId ?? 'guest'}',
        ) ??
        const <String>[];
    final operations = <int, bool>{};
    for (final value in values) {
      final parts = value.split(':');
      final id = parts.length == 2 ? int.tryParse(parts.first) : null;
      if (id != null) operations[id] = parts.last == '1';
    }
    return operations;
  }

  static Future<void> saveFavouriteSyncOperations(
    Map<int, bool> operations,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await getUserId();
    await prefs.setStringList(
      '${_keyFavouriteSyncOperations}_${userId ?? 'guest'}',
      operations.entries
          .map((entry) => '${entry.key}:${entry.value ? 1 : 0}')
          .toList(growable: false),
    );
  }

  static Future<String?> getCategoryLayout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCategoryLayout);
  }

  static Future<void> saveCategoryLayout(String layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCategoryLayout, layout);
  }

  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _keyToken);
    await _secureStorage.delete(key: _keyRefreshToken);
    await prefs.remove(_keyHasSecureAuth);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyUserId);
  }
}
