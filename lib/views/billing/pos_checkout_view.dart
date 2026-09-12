import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/cart_checkout.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/ui_breakpoints.dart';
import '../../widgets/workspace_ui.dart';

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
    await Future.wait([_fetchCategories(), _fetchAvailableProducts(reset: true)]);
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
        SizedBox(
          height: 44,
          child: TextField(
            onChanged: _setSearch,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search product...',
              hintStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .45)),
              prefixIcon: const Icon(Icons.search_rounded, size: 19),
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _categoryFilters(),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _productGrid(_products, provider, wide),
        ),
      ]);
      return Padding(
        padding: EdgeInsets.all(wide ? 16 : 12),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: products),
                const SizedBox(width: 18),
                SizedBox(
                  width: 330,
                  child: CartPanel(pageContext: context),
                ),
              ])
            : Column(children: [
                Expanded(child: products),
                const SizedBox(height: 10),
                const CartSummaryBar(),
              ]),
      );
    });
  }

  Widget _productGrid(List<dynamic> products, AppProvider provider, bool wide) {
    final scheme = Theme.of(context).colorScheme;
    if (products.isEmpty) {
      return EmptyCanvas(
        icon: Icons.search_off_rounded,
        title: 'No products found',
        detail: 'Try another search term or category.',
      );
    }
    return GridView.builder(
      controller: _productsController,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: wide ? 210 : 165,
        childAspectRatio: wide ? .92 : (Ui.isCompact(context) ? 1.05 : 1.15),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (_, index) {
        if (index == products.length) {
          return Center(child: CircularProgressIndicator(color: scheme.primary));
        }
        final product = products[index];
        final stock = quantityValue(product['stockQuantity']);
        final inCart = provider.cartItems.containsKey(product['id']);
        final imageUrl = product['imageUrl'] as String? ?? '';
        return _productCard(
            product, imageUrl, stock, inCart, wide);
      },
    );
  }

  Widget _productCard(dynamic product, String imageUrl, double stock,
      bool inCart, bool wide) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: stock > 0
            ? () => context.read<AppProvider>().addToCart(product)
            : null,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: EdgeInsets.all(wide ? 10 : 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: inCart ? scheme.primary : scheme.outlineVariant,
              width: inCart ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: wide
              ? _wideProductCard(product, imageUrl, stock, inCart)
              : _compactProductCard(product, imageUrl, stock, inCart),
        ),
      ),
    );
  }

  Widget _wideProductCard(dynamic product, String imageUrl, double stock,
      bool inCart) {
    final scheme = Theme.of(context).colorScheme;
    final price = product['sellingPrice'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Container(
            width: double.infinity,
            color: scheme.surfaceContainerHighest.withValues(alpha: .5),
            child: imageUrl.isEmpty
                ? Icon(Icons.inventory_2_outlined,
                    size: 30, color: scheme.onSurface.withValues(alpha: .35))
                : Image.network(imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                        Icons.inventory_2_outlined,
                        size: 30,
                        color: scheme.onSurface.withValues(alpha: .35))),
          ),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        stock > 0
            ? '${formatProductQuantity(stock, product)} left'
            : 'Out of stock',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 9.5,
            color: stock > 0 ? scheme.primary : scheme.error,
            fontWeight: FontWeight.w800,
            letterSpacing: .4),
      ),
      const SizedBox(height: 3),
      Text(product['name'] ?? 'Untitled product',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12.5,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      _productPriceRow(price, stock, inCart),
    ]);
  }

  Widget _compactProductCard(dynamic product, String imageUrl, double stock,
      bool inCart) {
    final scheme = Theme.of(context).colorScheme;
    final price = product['sellingPrice'];
    return Row(children: [
      Container(
        width: 46,
        height: 46,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(7),
        ),
        child: imageUrl.isEmpty
            ? Icon(Icons.inventory_2_outlined,
                size: 20, color: scheme.onSurface.withValues(alpha: .35))
            : Image.network(imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: scheme.onSurface.withValues(alpha: .35))),
      ),
      const SizedBox(width: 8),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(product['name'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 12)),
        const SizedBox(height: 2),
        Text('₹$price / ${productUnit(product)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: stock > 0 ? scheme.primary : scheme.error,
                fontWeight: FontWeight.w800,
                fontSize: 12)),
      ])),
      const SizedBox(width: 6),
      _addChip(inCart, stock),
    ]);
  }

  Widget _addChip(bool inCart, double stock) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = stock > 0;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: enabled
            ? (inCart ? scheme.primary : scheme.primary.withValues(alpha: .1))
            : scheme.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: enabled
                ? (inCart
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: .4))
                : scheme.outlineVariant),
      ),
      child: Icon(
        inCart ? Icons.check_rounded : Icons.add_rounded,
        size: 16,
        color: enabled
            ? (inCart ? scheme.onPrimary : scheme.primary)
            : scheme.onSurface.withValues(alpha: .3),
      ),
    );
  }

  Widget _productPriceRow(dynamic price, double stock, bool inCart) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(
          child: Text('₹$price',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w900))),
      _addChip(inCart, stock),
    ]);
  }

  Widget _categoryFilters() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final category = index == 0 ? null : _categories[index - 1];
          final id = category?['id'] as int?;
          final selected = _selectedCategoryId == id;
          return InkWell(
            onTap: () => _selectCategory(id),
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? scheme.primary : scheme.surface,
                border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                category?['name'] ?? 'All products',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onSurface.withValues(alpha: .8),
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }
}