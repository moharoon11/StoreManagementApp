import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';

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
      final keepsSelection =
          items.any((item) => item['id'] == _selectedCategoryId);
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
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
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
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
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
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Upload failed: ${e.toString().replaceAll('Exception: ', '')}')));
              }
            }
          }

          final scheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Text(category == null ? 'Add category' : 'Edit category'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => showModalBottomSheet(
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
                            leading: const Icon(Icons.camera_alt_outlined),
                            title: const Text('Take a photo'),
                            onTap: () {
                              Navigator.pop(context);
                              pick(ImageSource.camera);
                            }),
                      ]),
                    ),
                  ),
                  child: Container(
                    width: 112,
                    height: 86,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .08),
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(14)),
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
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined,
                                          color: scheme.primary),
                                      const SizedBox(height: 4),
                                      const Text('Add image',
                                          style: TextStyle(fontSize: 11))
                                    ],
                                  ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration:
                        const InputDecoration(labelText: 'Category name')),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
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
                                body);
                          }
                          if (mounted) _fetchCategories();
                        },
                  child: const Text('Save')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 520;
    return Padding(
      padding: EdgeInsets.all(compact ? 10 : 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Browse categories',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: -.7)),
                const SizedBox(height: 3),
                Text('Choose a category to view its products.',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .65),
                        fontSize: 12))
              ])),
          FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: () => _showCategoryDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(compact ? 'Add' : 'Add category'))
        ]),
        const SizedBox(height: 14),
        Expanded(
            child: _categories.isEmpty
                ? _emptyCategories(context)
                : Row(children: [
                    SizedBox(
                        width: compact ? 88 : (width < 760 ? 108 : 136),
                        child: _categoryRail()),
                    const SizedBox(width: 10),
                    Expanded(child: _productsPane())
                  ])),
      ]),
    );
  }

  Widget _emptyCategories(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_tree_outlined,
              size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          const Text('Create your first category'),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: () => _showCategoryDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add category')),
        ]),
      );

  Widget _categoryRail() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: .92),
          border: Border(right: BorderSide(color: scheme.outlineVariant))),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 12),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final category = Map<String, dynamic>.from(_categories[index] as Map);
          final selected = category['id'] == _selectedCategoryId;
          final imageUrl = category['imageUrl'] as String? ?? '';
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _selectCategory(category['id'] as int),
              child: Ink(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: .12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 43,
                    height: 43,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary.withValues(alpha: .14)
                            : scheme.surfaceContainerHighest
                                .withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(10)),
                    child: imageUrl.isEmpty
                        ? Icon(Icons.category_outlined,
                            size: 20,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: .55))
                        : Image.network(imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                                Icons.category_outlined,
                                size: 20,
                                color: scheme.primary)),
                  ),
                  const SizedBox(height: 6),
                  Text(category['name'] ?? 'Untitled',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: selected ? scheme.primary : scheme.onSurface,
                          fontSize: 10,
                          height: 1.15,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600)),
                ]),
              ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: .94),
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(category['name'] ?? 'Category',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w800))),
          PopupMenuButton<String>(
              tooltip: 'Category actions',
              onSelected: (action) => action == 'edit'
                  ? _showCategoryDialog(category: category)
                  : _deleteCategory(category),
              itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit category'),
                            contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                            leading: Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent),
                            title: Text('Delete category',
                                style: TextStyle(color: Colors.redAccent)),
                            contentPadding: EdgeInsets.zero)),
                  ])
        ]),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 390;
          return Wrap(spacing: 7, runSpacing: 7, children: [
            _filterButton(
                icon: Icons.tune_rounded,
                label: narrow ? null : 'Filters',
                onTap: _showProductFilters),
            _filterButton(
                icon: Icons.search_rounded,
                label: 'Search',
                onTap: _showSearchSheet),
            _filterButton(
                icon: Icons.inventory_2_outlined,
                label: _inStockOnly ? 'In stock' : 'All products',
                selected: _inStockOnly,
                onTap: () => setState(() => _inStockOnly = !_inStockOnly)),
          ]);
        }),
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
                            style: TextStyle(
                                color:
                                    scheme.onSurface.withValues(alpha: .62))))
                    : GridView.builder(
                        controller: _productsController,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: .61),
                        itemCount:
                            visibleProducts.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == visibleProducts.length) {
                            return const Padding(
                                padding: EdgeInsets.all(12),
                                child:
                                    Center(child: CircularProgressIndicator()));
                          }
                          return _productCard(Map<String, dynamic>.from(
                              visibleProducts[index] as Map));
                        }))
      ]),
    );
  }

  int _stockFor(Map<String, dynamic> product) =>
      (product['stockQuantity'] as num?)?.toInt() ?? 0;

  Widget _filterButton({
    required IconData icon,
    String? label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: .12) : scheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 9 : 10),
          decoration: BoxDecoration(
              border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant),
              borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: selected ? scheme.primary : null),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: selected ? scheme.primary : scheme.onSurface,
                      fontWeight: FontWeight.w700))
            ]
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
                child: const Text('Reset')),
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done')),
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
                      })),
        ),
      ),
    );
    controller.dispose();
  }

  Widget _productCard(Map<String, dynamic> product) {
    final scheme = Theme.of(context).colorScheme;
    final image = product['imageUrl'] as String? ?? '';
    final stock = _stockFor(product);
    final price = product['sellingPrice'];
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .025),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Stack(children: [
          Positioned.fill(
              child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .055),
                borderRadius: BorderRadius.circular(9)),
            child: image.isEmpty
                ? Icon(Icons.inventory_2_outlined,
                    size: 34, color: scheme.primary.withValues(alpha: .7))
                : Image.network(image,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                        Icons.inventory_2_outlined,
                        size: 34,
                        color: scheme.primary.withValues(alpha: .7))),
          )),
          Positioned(
              top: 5,
              right: 5,
              child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: .92),
                      shape: BoxShape.circle),
                  child: Icon(Icons.favorite_border_rounded,
                      size: 15, color: scheme.primary)))
        ])),
        const SizedBox(height: 7),
        Text(product['name']?.toString() ?? 'Untitled product',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12, height: 1.2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Row(children: [
          Text('₹${price ?? '—'}',
              style: TextStyle(
                  fontSize: 14,
                  color: scheme.secondary,
                  fontWeight: FontWeight.w900)),
          const Spacer(),
          Text(stock > 0 ? '$stock left' : 'Out',
              style: TextStyle(
                  fontSize: 10,
                  color: stock > 0 ? scheme.primary : scheme.error,
                  fontWeight: FontWeight.w700))
        ])
      ]),
    );
  }
}
