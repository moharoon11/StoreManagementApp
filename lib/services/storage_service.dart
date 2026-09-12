import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'jwt_token';
  static const String _keyUsername = 'username';
  static const String _keyUserId = 'user_id';
  static const String _keyTheme = 'app_theme';
  static const String _keyFavouriteProductIds = 'favourite_product_ids';
  static const String _keyCategoryLayout = 'category_layout';

  static Future<void> saveAuthData(
      {required String token,
      required String username,
      required int userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUsername, username);
    await prefs.setInt(_keyUserId, userId);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
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
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyUserId);
  }
}
