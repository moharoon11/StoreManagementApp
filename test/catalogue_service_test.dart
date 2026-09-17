import 'package:flutter_test/flutter_test.dart';
import 'package:store_management_app/services/catalogue_service.dart';

void main() {
  group('CatalogueService.extractProducts', () {
    test('accepts a direct list', () {
      final products = CatalogueService.extractProducts([
        {'id': 1, 'name': 'Tea'},
      ]);

      expect(products.single['name'], 'Tea');
    });

    test('accepts nested paged response shapes', () {
      final products = CatalogueService.extractProducts({
        'success': true,
        'data': {
          'items': [
            {'id': 2, 'name': 'Coffee'},
          ],
        },
      });

      expect(products.single['id'], 2);
    });

    test('deduplicates products by ID', () {
      final products = CatalogueService.uniqueProducts([
        {'id': 1, 'name': 'Tea'},
        {'id': 1, 'name': 'Tea duplicate'},
      ]);

      expect(products, hasLength(1));
      expect(products.single['name'], 'Tea');
    });
  });
}
