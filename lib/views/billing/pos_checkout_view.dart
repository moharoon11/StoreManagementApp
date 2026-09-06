import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/cart_checkout.dart';
import '../../utils/quantity_utils.dart';

class PosCheckoutView extends StatefulWidget {
  const PosCheckoutView({Key? key}) : super(key: key);

  @override
  State<PosCheckoutView> createState() => _PosCheckoutViewState();
}

class _PosCheckoutViewState extends State<PosCheckoutView> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  String _searchTerm = '';
  int? _selectedCategoryId;
  int _currentPage = 1;
  bool _hasMore = true;
  Timer? _searchDebounce;
  final ScrollController _productsController = ScrollController();

  static const _pageSize = 36;

  @override
  void initState() {
    super.initState();
    _productsController.addListener(_loadMoreWhenNeeded);
    _loadCatalogue();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _productsController
      ..removeListener(_loadMoreWhenNeeded)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadCatalogue() async {
    await Future.wait(
        [_fetchCategories(), _fetchAvailableProducts(reset: true)]);
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await ApiService.get(ApiConfig.categories);
      if (res['success'] == true && mounted) {
        setState(() => _categories = res['data'] ?? []);
      }
    } catch (_) {
      // Selling can still continue without category filters.
    }
  }

  void _loadMoreWhenNeeded() {
    if (_productsController.hasClients &&
        _productsController.position.extentAfter < 360) {
      _fetchAvailableProducts();
    }
  }

  Future<void> _fetchAvailableProducts({bool reset = false}) async {
    if (_isLoadingMore || (!reset && (!_hasMore || _isLoading))) return;
    final nextPage = reset ? 1 : _currentPage + 1;
    setState(() {
      if (reset) {
        _isLoading = true;
        _hasMore = true;
      } else {
        _isLoadingMore = true;
      }
    });
    try {
      final params = <String, String>{
        'pageNumber': '$nextPage',
        'pageSize': '$_pageSize',
      };
      if (_searchTerm.trim().isNotEmpty)
        params['searchTerm'] = _searchTerm.trim();
      if (_selectedCategoryId != null) {
        params['categoryId'] = _selectedCategoryId.toString();
      }
      final res =
          await ApiService.get(ApiConfig.products, queryParameters: params);
      if (res['success'] == true && mounted) {
        final page = res['data'] as Map<String, dynamic>;
        final items = (page['items'] as List?) ?? [];
        setState(() {
          _products = reset ? items : [..._products, ...items];
          _currentPage = nextPage;
          _hasMore = items.length >= _pageSize;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _setSearch(String value) {
    _searchTerm = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchAvailableProducts(reset: true);
    });
  }

  void _selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    setState(() => _selectedCategoryId = categoryId);
    _fetchAvailableProducts(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 860;
      final products = Column(children: [
        TextField(
            onChanged: _setSearch,
            decoration: const InputDecoration(
                hintText: 'Search product...',
                prefixIcon: Icon(Icons.search_rounded))),
        const SizedBox(height: 10),
        _categoryFilters(),
        const SizedBox(height: 12),
        Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _productGrid(_products, provider, wide))
      ]);
      return Padding(
          padding: EdgeInsets.all(wide ? 16 : 10),
          child: wide
              ? Row(children: [
                  Expanded(flex: 3, child: products),
                  const SizedBox(width: 18),
                  SizedBox(width: 330, child: CartPanel(pageContext: context)),
                ])
              : Column(children: [
                  Expanded(child: products),
                  const SizedBox(height: 10),
                  const CartSummaryBar(),
                ]));
    });
  }

  Widget _productGrid(List<dynamic> products, AppProvider provider, bool wide) {
    final scheme = Theme.of(context).colorScheme;
    if (products.isEmpty) {
      return Center(
          child: Text('No products found. Try another category or search.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: .6))));
    }
    return GridView.builder(
      controller: _productsController,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: wide ? 230 : 185,
          childAspectRatio: wide ? .94 : 1.34,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10),
      itemCount: products.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (_, index) {
        if (index == products.length) {
          return Center(
              child: CircularProgressIndicator(color: scheme.primary));
        }
        final product = products[index];
        final stock = quantityValue(product['stockQuantity']);
        final inCart = provider.cartItems.containsKey(product['id']);
        final imageUrl = product['imageUrl'] as String? ?? '';
        return Material(
            color: scheme.surface,
            elevation: 1,
            shadowColor: scheme.shadow.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
                onTap: stock > 0 ? () => provider.addToCart(product) : null,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                    padding: EdgeInsets.all(wide ? 11 : 9),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color:
                                inCart ? scheme.primary : scheme.outlineVariant,
                            width: inCart ? 1.6 : 1),
                        borderRadius: BorderRadius.circular(13)),
                    child: wide
                        ? _wideProductCard(product, imageUrl, stock, inCart)
                        : _compactProductCard(
                            product, imageUrl, stock, inCart))));
      },
    );
  }

  Widget _wideProductCard(
          dynamic product, String imageUrl, double stock, bool inCart) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _productImage(imageUrl, double.infinity)),
        const SizedBox(height: 8),
        Text(product['categoryName'] ?? 'PRODUCT',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 9,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(product['name'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
        const SizedBox(height: 6),
        _productPriceRow(product, stock, inCart),
      ]);

  Widget _compactProductCard(
          dynamic product, String imageUrl, double stock, bool inCart) =>
      Row(children: [
        _productImage(imageUrl, 48),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product['name'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
          const SizedBox(height: 4),
          _productPriceRow(product, stock, inCart, compact: true),
        ]))
      ]);

  Widget _productImage(String imageUrl, double size) => Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: .5),
          borderRadius: BorderRadius.circular(10)),
      child: imageUrl.isEmpty
          ? Icon(Icons.inventory_2_outlined,
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: .4),
              size: 28)
          : Image.network(imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .4),
                  size: 28)));

  Widget _productPriceRow(dynamic product, double stock, bool inCart,
          {bool compact = false}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
            child: Text('₹${product['sellingPrice']} / ${productUnit(product)}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: stock > 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 15))),
        const SizedBox(width: 4),
        Icon(inCart ? Icons.check_circle_rounded : Icons.add_circle_outline,
            color: stock > 0
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: .35),
            size: compact ? 18 : 21)
      ]);

  Widget _categoryFilters() => SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final category = index == 0 ? null : _categories[index - 1];
            final id = category?['id'] as int?;
            final selected = _selectedCategoryId == id;
            final scheme = Theme.of(context).colorScheme;
            return FilterChip(
              selected: selected,
              showCheckmark: false,
              label: Text(category?['name'] ?? 'All products',
                  overflow: TextOverflow.ellipsis),
              onSelected: (_) => _selectCategory(id),
              selectedColor: scheme.primary.withValues(alpha: .14),
              labelStyle: TextStyle(
                  color: selected ? scheme.primary : scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
              side: BorderSide(
                  color: selected ? scheme.primary : scheme.outlineVariant),
              backgroundColor: scheme.surface,
            );
          },
        ),
      );
}
