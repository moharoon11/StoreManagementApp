import '../config/api_config.dart';
import 'api_service.dart';

/// Server counterpart for the locally cached favourites list.
///
/// The UI never waits for these calls: [AppProvider] applies the change to its
/// local cache first, then sends it here in the background.
abstract final class FavouriteService {
  static Future<Set<int>> fetchIds() async {
    final response = await ApiService.get(ApiConfig.favourites);
    return _extractIds(response);
  }

  static Future<void> setFavourite({
    required int productId,
    required bool isFavourite,
  }) {
    if (isFavourite) {
      return ApiService.post('${ApiConfig.favourites}/$productId', const {});
    }
    return ApiService.delete('${ApiConfig.favourites}/$productId');
  }

  static Set<int> _extractIds(dynamic value) {
    if (value is num) return {value.toInt()};
    if (value is String) {
      final id = int.tryParse(value);
      return id == null ? const <int>{} : {id};
    }
    if (value is List) {
      return value.expand(_extractIds).toSet();
    }
    if (value is! Map) return const <int>{};

    final map = Map<String, dynamic>.from(value);
    for (final key in const [
      'productIds',
      'favouriteProductIds',
      'favoriteProductIds',
      'favourites',
      'favorites',
      'items',
      'data',
      'result',
    ]) {
      if (map.containsKey(key)) return _extractIds(map[key]);
    }

    final productId = map['productId'] ?? map['id'];
    if (productId is num) return {productId.toInt()};
    if (productId is String) {
      final id = int.tryParse(productId);
      if (id != null) return {id};
    }
    return const <int>{};
  }
}
