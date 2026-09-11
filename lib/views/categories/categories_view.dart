import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/adaptive_image_service.dart';
import '../../services/api_service.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/adaptive_image_preview.dart';
import '../../widgets/cart_checkout.dart';
import '../../widgets/workspace_ui.dart';

class CategoriesView extends StatefulWidget {
  const CategoriesView({super.key});

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  static const _pageSize = 30;

  final ScrollController _productsController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _isLoadingProducts = false;
  bool _isLoadingMore = false;
  bool _hasMoreProducts = true;
  int _page = 1;
  int? _selectedCategoryId;
  String _search = '';
  bool _inStockOnly = false;
  List<dynamic> _categories = [];
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _productsController.addListener(_loadMoreWhenNeeded);
    _fetchCategories();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _productsController
      ..removeListener(_loadMoreWhenNeeded)
      ..dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(ApiConfig.categories);
      final items = res['success'] == true ? (res['data'] as List? ?? []) : [];
      if (!mounted) return;
      final keepsSelection =
          items.any((item) => item['id'] == _selectedCategoryId);
      setState(() {
        _categories = items;
        _selectedCategoryId = keepsSelection
            ? _selectedCategoryId
            : (items.isNotEmpty ? items.first['id'] as int? : null);
        _isLoading = false;
        if (_selectedCategoryId == null) {
          _products = [];
        }
      });
      if (_selectedCategoryId != null) {
        await _fetchProducts(reset: true);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadMoreWhenNeeded() {
    if (_productsController.hasClients &&
        _productsController.position.extentAfter < 320) {
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts({bool reset = false}) async {
    if (_selectedCategoryId == null ||
        _isLoadingMore ||
        (!reset && (!_hasMoreProducts || _isLoadingProducts))) {
      return;
    }

    final nextPage = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _isLoadingProducts = true;
        _hasMoreProducts = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final res = await ApiService.get(ApiConfig.products, queryParameters: {
        'categoryId': _selectedCategoryId.toString(),
        'pageNumber': nextPage.toString(),
        'pageSize': _pageSize.toString(),
        if (_search.isNotEmpty) 'searchTerm': _search,
      });

      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final items = data['items'] as List? ?? [];
      setState(() {
        _products = reset ? items : [..._products, ...items];
        _page = nextPage;
        _hasMoreProducts = items.length >= _pageSize;
        _isLoadingProducts = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _isLoadingMore = false;
      });
    }
  }

  void _selectCategory(int id) {
    if (_selectedCategoryId == id) return;
    setState(() {
      _selectedCategoryId = id;
      _search = '';
      _inStockOnly = false;
      _searchController.clear();
    });
    _fetchProducts(reset: true);
  }

  void _setSearch(String value) {
    _search = value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      _fetchProducts(reset: true);
    });
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final name = (category['name'] ?? 'this category').toString();
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    try {
      await ApiService.delete('${ApiConfig.categories}/${category['id']}');
      await _fetchCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final nameController = TextEditingController(text: category?['name'] ?? '');
    String imageUrl = category?['imageUrl'] ?? '';
    XFile? localImage;
    bool uploading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pick() async {
            try {
              final image = await AdaptiveImageService.pickForUser(
                context,
                sheetTitle: 'Category image',
                galleryLabel: 'Choose category image',
              );
              if (image == null) return;
              setDialogState(() {
                localImage = image;
                uploading = true;
              });
              final uploaded = await ApiService.uploadImage(image);
              if (uploaded != null) {
                setDialogState(() {
                  imageUrl = uploaded;
                  uploading = false;
                });
              }
            } catch (e) {
              setDialogState(() => uploading = false);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
                  ),
                ),
              );
            }
          }

          final scheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Text(category == null ? 'Add category' : 'Edit category'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: pick,
                    child: Container(
                      width: 124,
                      height: 96,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: uploading
                          ? const Center(child: CircularProgressIndicator())
                          : AdaptiveImagePreview(
                              pickedImage: localImage,
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text('Add image'),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Category name',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: uploading
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(dialogContext);
                        final body = {'name': name, 'imageUrl': imageUrl};
                        if (category == null) {
                          await ApiService.post(ApiConfig.categories, body);
                        } else {
                          await ApiService.put(
                            '${ApiConfig.categories}/${category['id']}',
                            body,
                          );
                        }
                        if (mounted) _fetchCategories();
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, dynamic>? _currentCategory() {
    for (final item in _categories) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == _selectedCategoryId) return map;
    }
    return null;
  }

  double _stockFor(Map<String, dynamic> product) =>
      quantityValue(product['stockQuantity']);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return WorkspacePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageIntro(
              eyebrow: 'Categories',
              title: 'Build your catalogue structure',
              description:
                  'Create category groups first, then attach products to them inside a calmer browsing layout.',
              action: FilledButton.icon(
                onPressed: () => _showCategoryDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add category'),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: EmptyCanvas(
                icon: Icons.account_tree_outlined,
                title: 'No categories yet',
                detail:
                    'Create your first category to start organising products.',
              ),
            ),
          ],
        ),
      );
    }

    final currentCategory = _currentCategory();
    final visibleProducts = _inStockOnly
        ? _products
            .where((product) =>
                _stockFor(Map<String, dynamic>.from(product as Map)) > 0)
            .toList()
        : _products;
    final compact = MediaQuery.sizeOf(context).width < 760;

    return WorkspacePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(
            eyebrow: 'Categories',
            title: 'Browse by collection',
            description:
                'A full category library on larger screens and cleaner category chips on smaller screens. Products resize safely instead of collapsing.',
            action: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _fetchCategories,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
                FilledButton.icon(
                  onPressed: () => _showCategoryDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add category'),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 14 : 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1020;
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 274,
                            child: _CategoryLibrary(
                              categories: _categories,
                              selectedCategoryId: _selectedCategoryId,
                              onTap: _selectCategory,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _ProductCollection(
                              category: currentCategory,
                              searchController: _searchController,
                              onSearchChanged: _setSearch,
                              inStockOnly: _inStockOnly,
                              onToggleInStock: () => setState(
                                () => _inStockOnly = !_inStockOnly,
                              ),
                              onEditCategory: currentCategory == null
                                  ? null
                                  : () => _showCategoryDialog(
                                      category: currentCategory),
                              onDeleteCategory: currentCategory == null
                                  ? null
                                  : () => _deleteCategory(currentCategory),
                              products: visibleProducts,
                              isLoadingProducts: _isLoadingProducts,
                              isLoadingMore: _isLoadingMore,
                              controller: _productsController,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 82,
                            child: _MobileCategoryStrip(
                              categories: _categories,
                              selectedCategoryId: _selectedCategoryId,
                              onTap: _selectCategory,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _ProductCollection(
                              category: currentCategory,
                              searchController: _searchController,
                              onSearchChanged: _setSearch,
                              inStockOnly: _inStockOnly,
                              onToggleInStock: () => setState(
                                () => _inStockOnly = !_inStockOnly,
                              ),
                              onEditCategory: currentCategory == null
                                  ? null
                                  : () => _showCategoryDialog(
                                      category: currentCategory),
                              onDeleteCategory: currentCategory == null
                                  ? null
                                  : () => _deleteCategory(currentCategory),
                              products: visibleProducts,
                              isLoadingProducts: _isLoadingProducts,
                              isLoadingMore: _isLoadingMore,
                              controller: _productsController,
                            ),
                          ),
                        ],
                      );
              },
            ),
          ),
          if (!compact &&
              !context
                  .select<AppProvider, bool>((p) => p.cartItems.isEmpty)) ...[
            const SizedBox(height: 14),
            const CartSummaryBar(),
          ],
        ],
      ),
    );
  }
}

class _CategoryLibrary extends StatelessWidget {
  const _CategoryLibrary({
    required this.categories,
    required this.selectedCategoryId,
    required this.onTap,
  });

  final List<dynamic> categories;
  final int? selectedCategoryId;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category library',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Choose the collection you want to review.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: .62),
                ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final category =
                    Map<String, dynamic>.from(categories[index] as Map);
                final selected = category['id'] == selectedCategoryId;
                return _CategoryTile(
                  category: category,
                  selected: selected,
                  onTap: () => onTap(category['id'] as int),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCategoryStrip extends StatelessWidget {
  const _MobileCategoryStrip({
    required this.categories,
    required this.selectedCategoryId,
    required this.onTap,
  });

  final List<dynamic> categories;
  final int? selectedCategoryId;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final category = Map<String, dynamic>.from(categories[index] as Map);
        final selected = category['id'] == selectedCategoryId;
        return SizedBox(
          width: 138,
          child: _CategoryTile(
            category: category,
            selected: selected,
            compact: true,
            onTap: () => onTap(category['id'] as int),
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final Map<String, dynamic> category;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = (category['imageUrl'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: .14)
                : scheme.surfaceContainerHighest.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(compact ? 20 : 24),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: .22)
                  : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 44 : 58,
                height: compact ? 44 : 58,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withValues(alpha: .12)
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(compact ? 14 : 18),
                ),
                child: imageUrl.isEmpty
                    ? Icon(
                        Icons.category_outlined,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurface.withValues(alpha: .55),
                        size: compact ? 20 : 24,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.category_outlined,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: .55),
                          size: compact ? 20 : 24,
                        ),
                      ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (category['name'] ?? 'Untitled').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (compact
                              ? Theme.of(context).textTheme.bodyMedium
                              : Theme.of(context).textTheme.titleSmall)
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selected
                          ? 'Selected collection'
                          : 'Tap to explore products',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: .6),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCollection extends StatelessWidget {
  const _ProductCollection({
    required this.category,
    required this.searchController,
    required this.onSearchChanged,
    required this.inStockOnly,
    required this.onToggleInStock,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.products,
    required this.isLoadingProducts,
    required this.isLoadingMore,
    required this.controller,
  });

  final Map<String, dynamic>? category;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool inStockOnly;
  final VoidCallback onToggleInStock;
  final VoidCallback? onEditCategory;
  final VoidCallback? onDeleteCategory;
  final List<dynamic> products;
  final bool isLoadingProducts;
  final bool isLoadingMore;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    if (category == null) {
      return const EmptyCanvas(
        icon: Icons.inventory_2_outlined,
        title: 'Choose a category',
        detail: 'Pick one of your collections to load its products.',
      );
    }

    final imageUrl = (category!['imageUrl'] ?? '').toString();

    return SurfacePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final phone = constraints.maxWidth < 460;
          final compact = constraints.maxWidth < 760;
          final columns = phone
              ? 1
              : math.max(
                  1,
                  (constraints.maxWidth / (compact ? 300 : 228)).floor(),
                );
          final useList = phone;
          final mainExtent = columns == 1 && !useList
              ? 148.0
              : phone
                  ? 216.0
                  : 292.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CollectionHeading(
                            imageUrl: imageUrl, category: category!),
                        const SizedBox(height: 12),
                        _CollectionMenu(
                          onEditCategory: onEditCategory,
                          onDeleteCategory: onDeleteCategory,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _CollectionHeading(
                            imageUrl: imageUrl,
                            category: category!,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _CollectionMenu(
                          onEditCategory: onEditCategory,
                          onDeleteCategory: onDeleteCategory,
                        ),
                      ],
                    ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: compact ? constraints.maxWidth : 300,
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search inside this category',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  FilterChip(
                    selected: inStockOnly,
                    showCheckmark: false,
                    label: Text(inStockOnly ? 'In stock only' : 'All products'),
                    onSelected: (_) => onToggleInStock(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: isLoadingProducts
                    ? const Center(child: CircularProgressIndicator())
                    : products.isEmpty
                        ? EmptyCanvas(
                            icon: Icons.inventory_2_outlined,
                            title: 'No products to show',
                            detail: inStockOnly
                                ? 'There are no in-stock products in this category.'
                                : 'Add products here or try a different search.',
                          )
                        : useList
                            ? ListView.separated(
                                controller: controller,
                                itemCount:
                                    products.length + (isLoadingMore ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  if (index == products.length) {
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  return _ProductCard(
                                    product: Map<String, dynamic>.from(
                                        products[index] as Map),
                                    compact: true,
                                  );
                                },
                              )
                            : GridView.builder(
                                controller: controller,
                                itemCount:
                                    products.length + (isLoadingMore ? 1 : 0),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  mainAxisExtent: mainExtent,
                                ),
                                itemBuilder: (context, index) {
                                  if (index == products.length) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  return _ProductCard(
                                    product: Map<String, dynamic>.from(
                                        products[index] as Map),
                                    compact: columns == 1,
                                    dense: phone,
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

class _CollectionHeading extends StatelessWidget {
  const _CollectionHeading({
    required this.imageUrl,
    required this.category,
  });

  final String imageUrl;
  final Map<String, dynamic> category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(20),
          ),
          child: imageUrl.isEmpty
              ? const Icon(Icons.category_outlined)
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.category_outlined),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (category['name'] ?? 'Category').toString(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Products inside this collection',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: .62),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionMenu extends StatelessWidget {
  const _CollectionMenu({
    required this.onEditCategory,
    required this.onDeleteCategory,
  });

  final VoidCallback? onEditCategory;
  final VoidCallback? onDeleteCategory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          onEditCategory?.call();
        } else if (value == 'delete') {
          onDeleteCategory?.call();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit category')),
        PopupMenuItem(value: 'delete', child: Text('Delete category')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .24),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.more_horiz_rounded, size: 18),
            SizedBox(width: 8),
            Text('Category'),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.compact,
    this.dense = false,
  });

  final Map<String, dynamic> product;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final scheme = Theme.of(context).colorScheme;
    final image = (product['imageUrl'] ?? '').toString();
    final stock = quantityValue(product['stockQuantity']);
    final inCart = provider.cartItems.containsKey(product['id']);

    if (compact) {
      return SurfacePanel(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _ProductImage(image: image, compact: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (product['name'] ?? 'Untitled product').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (product['categoryName'] ?? 'Uncategorised').toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                        ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₹${product['sellingPrice'] ?? '—'}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: scheme.onSurface,
                                  ),
                        ),
                      ),
                      _CartAction(
                          product: product, stock: stock, inCart: inCart),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StatusPill(
                    label: stock > 0
                        ? '${formatProductQuantity(stock, product)} left'
                        : 'Out of stock',
                    color: stock > 0 ? scheme.secondary : scheme.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SurfacePanel(
      padding: EdgeInsets.all(dense ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(image: image, dense: dense),
          SizedBox(height: dense ? 10 : 14),
          Text(
            (product['categoryName'] ?? 'Uncategorised').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  letterSpacing: dense ? .7 : 1.2,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            (product['name'] ?? 'Untitled product').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: dense
                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    )
                : Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Row(
            crossAxisAlignment:
                dense ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${product['sellingPrice'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (dense
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.headlineSmall)
                          ?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    SizedBox(height: dense ? 4 : 8),
                    if (dense)
                      Text(
                        stock > 0
                            ? '${formatProductQuantity(stock, product)} left'
                            : 'Out of stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  stock > 0 ? scheme.secondary : scheme.error,
                            ),
                      )
                    else
                      StatusPill(
                        label: stock > 0
                            ? '${formatProductQuantity(stock, product)} left'
                            : 'Out of stock',
                        color: stock > 0 ? scheme.secondary : scheme.error,
                      ),
                  ],
                ),
              ),
              SizedBox(width: dense ? 8 : 12),
              _CartAction(
                product: product,
                stock: stock,
                inCart: inCart,
                dense: dense,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.image,
    this.compact = false,
    this.dense = false,
  });

  final String image;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: compact ? 86 : double.infinity,
      height: compact
          ? 86
          : dense
              ? 86
              : 118,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .36),
        borderRadius: BorderRadius.circular(dense ? 18 : 22),
      ),
      child: image.isEmpty
          ? Icon(
              Icons.inventory_2_outlined,
              color: scheme.onSurface.withValues(alpha: .36),
              size: compact
                  ? 34
                  : dense
                      ? 30
                      : 42,
            )
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.inventory_2_outlined,
                color: scheme.onSurface.withValues(alpha: .36),
                size: compact
                    ? 34
                    : dense
                        ? 30
                        : 42,
              ),
            ),
    );
  }
}

class _CartAction extends StatelessWidget {
  const _CartAction({
    required this.product,
    required this.stock,
    required this.inCart,
    this.dense = false,
  });

  final Map<String, dynamic> product;
  final double stock;
  final bool inCart;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: stock > 0
          ? () => context.read<AppProvider>().addToCart(product)
          : null,
      borderRadius: BorderRadius.circular(dense ? 14 : 18),
      child: Container(
        width: dense ? 40 : 48,
        height: dense ? 40 : 48,
        decoration: BoxDecoration(
          color: stock > 0
              ? (inCart
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: .12))
              : scheme.surfaceContainerHighest.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(dense ? 14 : 18),
        ),
        child: Icon(
          inCart ? Icons.check_rounded : Icons.add_rounded,
          size: dense ? 18 : 22,
          color: stock > 0
              ? (inCart ? scheme.onPrimary : scheme.primary)
              : scheme.onSurface.withValues(alpha: .35),
        ),
      ),
    );
  }
}
