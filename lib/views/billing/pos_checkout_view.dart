import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/cart_checkout.dart';
import '../../widgets/workspace_ui.dart';

class PosCheckoutView extends StatefulWidget {
  const PosCheckoutView({super.key});

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
    await Future.wait([
      _fetchCategories(),
      _fetchAvailableProducts(reset: true),
    ]);
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
        _productsController.position.extentAfter < 320) {
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
      if (_searchTerm.trim().isNotEmpty) {
        params['searchTerm'] = _searchTerm.trim();
      }
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
    return WorkspacePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(
            eyebrow: 'Sell',
            title: 'Checkout workspace',
            description:
                'Tap items to add them to the current sale. The product browser and cart now stay compact and readable across screen sizes.',
            action: provider.cartItems.isEmpty
                ? null
                : StatusPill(
                    label:
                        '${formatQuantity(provider.cartCount)} items · ₹${provider.cartTotal.toStringAsFixed(0)}',
                    color: Theme.of(context).colorScheme.primary,
                  ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 990;
                final catalogue = _ProductBrowser(
                  categories: _categories,
                  selectedCategoryId: _selectedCategoryId,
                  onSelectCategory: _selectCategory,
                  onSearchChanged: _setSearch,
                  isLoading: _isLoading,
                  isLoadingMore: _isLoadingMore,
                  products: _products,
                  controller: _productsController,
                );
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 6, child: catalogue),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 320,
                            child: CartPanel(pageContext: context),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: catalogue),
                          const SizedBox(height: 14),
                          const CartSummaryBar(),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductBrowser extends StatelessWidget {
  const _ProductBrowser({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    required this.onSearchChanged,
    required this.isLoading,
    required this.isLoadingMore,
    required this.products,
    required this.controller,
  });

  final List<dynamic> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelectCategory;
  final ValueChanged<String> onSearchChanged;
  final bool isLoading;
  final bool isLoadingMore;
  final List<dynamic> products;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = math.max(
            1,
            (constraints.maxWidth / 214).floor(),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: constraints.maxWidth < 420 ? constraints.maxWidth : 320,
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search product',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final category = index == 0 ? null : categories[index - 1];
                    final id = category?['id'] as int?;
                    final selected = selectedCategoryId == id;
                    return FilterChip(
                      selected: selected,
                      showCheckmark: false,
                      label: Text(category?['name'] ?? 'All products'),
                      onSelected: (_) => onSelectCategory(id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : products.isEmpty
                        ? const EmptyCanvas(
                            icon: Icons.point_of_sale_outlined,
                            title: 'No products found',
                            detail:
                                'Try another category or a different search.',
                          )
                        : GridView.builder(
                            controller: controller,
                            itemCount:
                                products.length + (isLoadingMore ? 1 : 0),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: columns == 1 ? 128 : 236,
                            ),
                            itemBuilder: (_, index) {
                              if (index == products.length) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final product = Map<String, dynamic>.from(
                                  products[index] as Map);
                              return _SellProductCard(
                                product: product,
                                compact: columns == 1,
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SellProductCard extends StatelessWidget {
  const _SellProductCard({
    required this.product,
    required this.compact,
  });

  final Map<String, dynamic> product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final scheme = Theme.of(context).colorScheme;
    final stock = quantityValue(product['stockQuantity']);
    final inCart = provider.cartItems.containsKey(product['id']);
    final imageUrl = (product['imageUrl'] ?? '').toString();

    final addAction = InkWell(
      onTap: stock > 0 ? () => provider.addToCart(product) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: stock > 0
              ? (inCart
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: .12))
              : scheme.surfaceContainerHighest.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          inCart ? Icons.check_rounded : Icons.add_rounded,
          color: stock > 0
              ? (inCart ? scheme.onPrimary : scheme.primary)
              : scheme.onSurface.withValues(alpha: .34),
        ),
      ),
    );

    if (compact) {
      return SurfacePanel(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _SellProductImage(imageUrl: imageUrl, compact: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (product['name'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (product['categoryName'] ?? 'Product').toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                        ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₹${product['sellingPrice']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      addAction,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SurfacePanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SellProductImage(imageUrl: imageUrl),
          const SizedBox(height: 10),
          Text(
            (product['categoryName'] ?? 'Product').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            (product['name'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '₹${product['sellingPrice']} / ${productUnit(product)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: stock > 0 ? scheme.primary : scheme.error,
                      ),
                ),
              ),
              addAction,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stock > 0
                ? '${formatProductQuantity(stock, product)} left'
                : 'Out of stock',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: stock > 0 ? scheme.secondary : scheme.error,
                ),
          ),
        ],
      ),
    );
  }
}

class _SellProductImage extends StatelessWidget {
  const _SellProductImage({
    required this.imageUrl,
    this.compact = false,
  });

  final String imageUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: compact ? 82 : double.infinity,
      height: compact ? 82 : 88,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: imageUrl.isEmpty
          ? Icon(
              Icons.inventory_2_outlined,
              color: scheme.onSurface.withValues(alpha: .34),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.inventory_2_outlined,
                color: scheme.onSurface.withValues(alpha: .34),
              ),
            ),
    );
  }
}
