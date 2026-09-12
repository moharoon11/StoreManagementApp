import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../utils/quantity_utils.dart';
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
      final keepsSelection = items.any((item) => item['id'] == _selectedCategoryId);
      setState(() {
        _categories = items;
        _selectedCategoryId = keepsSelection
            ? _selectedCategoryId
            : (items.isNotEmpty ? items.first['id'] as int? : null);
        _isLoading = false;
      });
      if (_selectedCategoryId != null) await _fetchProducts(reset: true);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadMoreWhenNeeded() {
    if (_productsController.hasClients &&
        _productsController.position.extentAfter < 280) {
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
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _selectCategory(int id) {
    if (_selectedCategoryId == id) return;
    setState(() {
      _selectedCategoryId = id;
      _search = '';
      _inStockOnly = false;
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
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
            onPressed: () => Navigator.pop(dialogContext, true),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final nameController = TextEditingController(text: category?['name'] ?? '');
    String imageUrl = category?['imageUrl'] ?? '';
    File? localImage;
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pick(ImageSource source) async {
              try {
                final image = await ImagePicker()
                    .pickImage(source: source, imageQuality: 80);
                if (image == null) return;
                setDialogState(() {
                  localImage = File(image.path);
                  uploading = true;
                });
                final uploaded = await ApiService.uploadImage(image.path);
                if (uploaded != null) {
                  setDialogState(() {
                    imageUrl = uploaded;
                    uploading = false;
                  });
                }
              } catch (e) {
                setDialogState(() => uploading = false);
              }
            }

            void sourceSheet() {
              showModalBottomSheet(
                context: context,
                builder: (_) => SafeArea(
                  child: Wrap(children: [
                    ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: const Text('Choose from gallery'),
                        onTap: () {
                          Navigator.pop(context);
                          pick(ImageSource.gallery);
                        }),
                    ListTile(
                        leading: const Icon(Icons.photo_camera_outlined),
                        title: const Text('Take a photo'),
                        onTap: () {
                          Navigator.pop(context);
                          pick(ImageSource.camera);
                        }),
                  ]),
                ),
              );
            }

            final scheme = Theme.of(context).colorScheme;
            return Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          category == null ? 'Add category' : 'Edit category',
                          style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: sourceSheet,
                    child: Container(
                      height: 92,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: .45),
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: uploading
                          ? const Center(child: CircularProgressIndicator())
                          : localImage != null
                              ? Image.file(localImage!, fit: BoxFit.contain)
                              : imageUrl.isNotEmpty
                                  ? Image.network(imageUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                          Icons.add_photo_alternate_outlined,
                                          color: scheme.primary))
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: scheme.primary),
                                        const SizedBox(width: 8),
                                        Text('Add category image',
                                            style: TextStyle(
                                                color: scheme.onSurface
                                                    .withValues(alpha: .6),
                                                fontSize: 12)),
                                      ],
                                    ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Category name'),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Save'),
                        onPressed: uploading
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) return;
                                Navigator.pop(sheetContext);
                                final body = {
                                  'name': name,
                                  'imageUrl': imageUrl,
                                };
                                if (category == null) {
                                  await ApiService.post(
                                      ApiConfig.categories, body);
                                } else {
                                  await ApiService.put(
                                      '${ApiConfig.categories}/${category['id']}',
                                      body);
                                }
                                if (mounted) _fetchCategories();
                              },
                      ),
                    ),
                  ]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const WorkspacePage(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 520;
    final extraCompact = width < 380;

    return WorkspacePage(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageIntro(
          eyebrow: 'Browse catalogue',
          title: 'Categories',
          description: 'Pick a collection to see its products.',
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: EdgeInsets.symmetric(horizontal: extraCompact ? 12 : 16),
            ),
            onPressed: () => _showCategoryDialog(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(extraCompact ? 'Add' : 'Add category'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _categories.isEmpty
              ? _emptyCategories(context)
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: extraCompact
                        ? 66
                        : (compact ? 84 : (width < 760 ? 102 : 132)),
                    child: _categoryRail(),
                  ),
                  SizedBox(width: extraCompact ? 8 : 10),
                  Expanded(child: _productsPane()),
                ]),
        ),
        if (!context.select<AppProvider, bool>((p) => p.cartItems.isEmpty)) ...[
          const SizedBox(height: 8),
          const CartSummaryBar(),
        ],
      ]),
    );
  }

  Widget _emptyCategories(BuildContext context) {
    return const EmptyCanvas(
      icon: Icons.account_tree_outlined,
      title: 'Create your first category',
      detail: 'Group your products into collections so they are easier to find.',
    );
  }

  Widget _categoryRail() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .92),
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 12),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final category = Map<String, dynamic>.from(_categories[index] as Map);
          final selected = category['id'] == _selectedCategoryId;
          final imageUrl = category['imageUrl'] as String? ?? '';
          return InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: () => _selectCategory(category['id'] as int),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: .1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 40,
                  height: 40,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: .14)
                        : scheme.surfaceContainerHighest.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: imageUrl.isEmpty
                      ? Icon(Icons.category_outlined,
                          size: 19,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: .55))
                      : Image.network(imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.category_outlined,
                              size: 19,
                              color: scheme.primary)),
                ),
                const SizedBox(height: 5),
                Text(category['name'] ?? 'Untitled',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: selected ? scheme.primary : scheme.onSurface,
                        fontSize: 9.5,
                        height: 1.15,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _productsPane() {
    final selected = _categories.firstWhere(
        (category) => category['id'] == _selectedCategoryId,
        orElse: () => null);
    if (selected == null) return const SizedBox();
    final category = Map<String, dynamic>.from(selected as Map);
    final scheme = Theme.of(context).colorScheme;
    final visibleProducts = _inStockOnly
        ? _products
            .where((product) =>
                _stockFor(Map<String, dynamic>.from(product as Map)) > 0)
            .toList()
        : _products;

    return LayoutBuilder(builder: (context, paneConstraints) {
      final tightPane = paneConstraints.maxWidth < 230;
      return Container(
        padding:
            EdgeInsets.fromLTRB(tightPane ? 7 : 10, 8, tightPane ? 7 : 10, 10),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: .94),
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(category['name'] ?? 'Category',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                if (tightPane)
                  const SizedBox(height: 2)
                else
                  const SizedBox(height: 4),
              ]),
            ),
            if (tightPane)
              PopupMenuButton<String>(
                tooltip: 'Category actions',
                onSelected: (action) => action == 'edit'
                    ? _showCategoryDialog(category: category)
                    : _deleteCategory(category),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit category')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            else ...[
              IconButton(
                tooltip: 'Edit category',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined,
                    size: 17,
                    color: scheme.onSurface.withValues(alpha: .6)),
                onPressed: () => _showCategoryDialog(category: category),
              ),
              IconButton(
                tooltip: 'Delete category',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline,
                    size: 17, color: scheme.error.withValues(alpha: .8)),
                onPressed: () => _deleteCategory(category),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _filterButton(
                icon: Icons.tune_rounded,
                label: tightPane ? null : 'Filters',
                onTap: _showProductFilters),
            const SizedBox(width: 6),
            _filterButton(
                icon: Icons.search_rounded,
                label: 'Search',
                onTap: _showSearchSheet),
            const SizedBox(width: 6),
            _filterButton(
                icon: Icons.inventory_2_rounded,
                label: _inStockOnly ? 'In stock' : 'All products',
                selected: _inStockOnly,
                onTap: () => setState(() => _inStockOnly = !_inStockOnly)),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoadingProducts
                ? const Center(child: CircularProgressIndicator())
                : visibleProducts.isEmpty
                    ? Center(
                        child: Text(
                            _inStockOnly
                                ? 'No products in stock.'
                                : 'No products in this category yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color:
                                    scheme.onSurface.withValues(alpha: .62),
                                fontSize: 12)),
                      )
                    : GridView.builder(
                        controller: _productsController,
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: tightPane ? 220 : 180,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: tightPane ? .74 : .61,
                        ),
                        itemCount:
                            visibleProducts.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == visibleProducts.length) {
                            return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(
                                    child: CircularProgressIndicator()));
                          }
                          return _productCard(
                              Map<String, dynamic>.from(
                                  visibleProducts[index] as Map),
                              compact: tightPane);
                        }),
          ),
        ]),
      );
    });
  }

  double _stockFor(Map<String, dynamic> product) =>
      quantityValue(product['stockQuantity']);

  Widget _filterButton({
    required IconData icon,
    String? label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: .12) : scheme.surface,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 9 : 10),
          decoration: BoxDecoration(
            border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: selected ? scheme.primary : null),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: selected ? scheme.primary : scheme.onSurface,
                      fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _showProductFilters() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Product filters'),
          content: StatefulBuilder(builder: (context, setDialogState) {
            return SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('In-stock products only'),
              value: _inStockOnly,
              onChanged: (value) {
                setState(() => _inStockOnly = value);
                setDialogState(() {});
              },
            );
          }),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _inStockOnly = false);
                Navigator.pop(context);
              },
              child: const Text('Reset'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );

  Future<void> _showSearchSheet() async {
    final controller = TextEditingController(text: _search);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: TextField(
          controller: controller,
          autofocus: true,
          onChanged: _setSearch,
          decoration: InputDecoration(
            hintText: 'Search in this category',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      controller.clear();
                      _setSearch('');
                    },
                  ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Widget _productCard(Map<String, dynamic> product, {bool compact = false}) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final inCart = provider.cartItems.containsKey(product['id']);
    final image = product['imageUrl'] as String? ?? '';
    final stock = _stockFor(product);
    final price = product['sellingPrice'];

    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(
            color: inCart ? scheme.primary : scheme.outlineVariant,
            width: inCart ? 1.4 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              color: scheme.primary.withValues(alpha: .055),
              child: image.isEmpty
                  ? Icon(Icons.inventory_2_outlined,
                      size: 32, color: scheme.primary.withValues(alpha: .7))
                  : Image.network(image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.inventory_2_outlined,
                          size: 32,
                          color: scheme.primary.withValues(alpha: .7))),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(product['name']?.toString() ?? 'Untitled product',
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: scheme.onSurface,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Row(children: [
          Expanded(
            flex: 3,
            child: Text('₹$price',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: scheme.primary, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 4,
            child: Text(
                stock > 0
                    ? '${formatProductQuantity(stock, product)} left'
                    : 'Out',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9.5,
                    color: stock > 0 ? scheme.primary : scheme.error,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          _addToCartButton(product, stock, inCart)
        ]),
      ]),
    );
  }

  Widget _addToCartButton(
      Map<String, dynamic> product, double stock, bool inCart) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: stock > 0
          ? () => context.read<AppProvider>().addToCart(product)
          : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: stock > 0
              ? (inCart ? scheme.primary : scheme.primary.withValues(alpha: .1))
              : scheme.surfaceContainerHighest.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: stock > 0
                  ? (inCart
                      ? scheme.primary
                      : scheme.primary.withValues(alpha: .4))
                  : scheme.outlineVariant),
        ),
        child: Icon(
          inCart ? Icons.check_rounded : Icons.add_rounded,
          size: 16,
          color: stock > 0
              ? (inCart ? scheme.onPrimary : scheme.primary)
              : scheme.onSurface.withValues(alpha: .35),
        ),
      ),
    );
  }
}