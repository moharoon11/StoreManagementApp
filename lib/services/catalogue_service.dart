import '../config/api_config.dart';
import 'api_service.dart';

/// One tolerant reader for the catalogue endpoints.
///
/// The hosted API has returned both a list and several paged response shapes
/// over time. Keeping that compatibility in one place prevents Sell and
/// Products from disagreeing about which products exist.
abstract final class CatalogueService {
  static const defaultPageSize = 30;

  static Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String searchTerm = '',
    int page = 1,
    int pageSize = defaultPageSize,
  }) async {
    final response = await ApiService.get(
      ApiConfig.products,
      queryParameters: {
        // These names match the deployed ASP.NET API contract exactly.
        'PageNumber': '$page',
        'PageSize': '$pageSize',
        if (categoryId != null) 'CategoryId': '$categoryId',
        if (searchTerm.trim().isNotEmpty) 'SearchTerm': searchTerm.trim(),
      },
    );
    return uniqueProducts(extractProducts(response));
  }

  /// Builds the all-products catalogue from category results. Category pages
  /// are reliable on the deployed API even when its unfiltered response is
  /// empty or malformed. A failure in one category must not hide the rest.
  static Future<List<Map<String, dynamic>>> fetchAcrossCategories(
    Iterable<dynamic> categories, {
    String searchTerm = '',
    int pageSize = defaultPageSize,
  }) async {
    final products = <Map<String, dynamic>>[];
    // Send these one at a time. The hosted API can reject simultaneous
    // catalogue requests, even though the same category works in Categories.
    for (final rawCategory in categories) {
      try {
        final category = Map<String, dynamic>.from(rawCategory as Map);
        final rawId = category['id'];
        final id = rawId is int ? rawId : int.tryParse('$rawId');
        if (id == null) continue;
        products.addAll(await fetchProducts(
          categoryId: id,
          searchTerm: searchTerm,
          pageSize: pageSize,
        ));
      } catch (_) {
        // A broken category must not hide products from the other categories.
      }
    }
    return uniqueProducts(products);
  }

  static List<Map<String, dynamic>> extractProducts(dynamic response) {
    if (response is List) return _maps(response);
    if (response is! Map) return const [];

    final map = Map<String, dynamic>.from(response);
    for (final key in const ['items', 'products', 'rows', 'data', 'result']) {
      final value = map[key];
      if (value is List) return _maps(value);
      if (value is Map) {
        final products = extractProducts(value);
        if (products.isNotEmpty) return products;
      }
    }
    return const [];
  }

  static List<Map<String, dynamic>> uniqueProducts(
    Iterable<Map<String, dynamic>> products,
  ) {
    final seen = <String>{};
    return [
      for (final product in products)
        if (seen.add(_productKey(product))) product,
    ];
  }

  static List<Map<String, dynamic>> _maps(Iterable<dynamic> items) => [
        for (final item in items)
          if (item is Map) Map<String, dynamic>.from(item),
      ];

  static String _productKey(Map<String, dynamic> product) {
    final id = product['id'];
    if (id != null) return 'id:$id';
    return 'fallback:${product['name']}:${product['categoryId']}';
  }
}
