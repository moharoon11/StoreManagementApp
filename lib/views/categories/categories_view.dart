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
    final narrow = MediaQuery.sizeOf(context).width < 640;
    return Padding(
      padding: EdgeInsets.all(narrow ? 16 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Categories',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 3),
                Text('Select a category to browse and manage its products.',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .65),
                        fontSize: 12))
              ])),
          FilledButton.icon(
              onPressed: () => _showCategoryDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(narrow ? 'Add' : 'Add category'))
        ]),
        const SizedBox(height: 18),
        Expanded(
            child: _categories.isEmpty
                ? _emptyCategories(context)
                : Row(children: [
                    SizedBox(width: narrow ? 112 : 230, child: _categoryRail()),
                    const SizedBox(width: 12),
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
          color: scheme.surface,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(18)),
      child: ListView.separated(
        padding: const EdgeInsets.all(7),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final category = Map<String, dynamic>.from(_categories[index] as Map);
          final selected = category['id'] == _selectedCategoryId;
          return Material(
            color: selected
                ? scheme.primary.withValues(alpha: .13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _selectCategory(category['id'] as int),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 5, 10),
                child: Row(children: [
                  Expanded(
                      child: Text(category['name'] ?? 'Untitled',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color:
                                  selected ? scheme.primary : scheme.onSurface,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600))),
                  PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: 'Category actions',
                      onSelected: (action) => action == 'edit'
                          ? _showCategoryDialog(category: category)
                          : _deleteCategory(category),
                      itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete',
                                    style: TextStyle(color: Colors.redAccent))),
                          ])
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(category['name'] ?? 'Category',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800))),
          IconButton(
              tooltip: 'Edit category',
              onPressed: () => _showCategoryDialog(category: category),
              icon: const Icon(Icons.edit_outlined, size: 19))
        ]),
        const SizedBox(height: 8),
        TextField(
            onChanged: _setSearch,
            decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search in this category',
                prefixIcon: Icon(Icons.search_rounded))),
        const SizedBox(height: 12),
        Expanded(
            child: _isLoadingProducts
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Text('No products in this category yet.',
                            style: TextStyle(
                                color:
                                    scheme.onSurface.withValues(alpha: .62))))
                    : ListView.separated(
                        controller: _productsController,
                        itemCount: _products.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == _products.length) {
                            return const Padding(
                                padding: EdgeInsets.all(12),
                                child:
                                    Center(child: CircularProgressIndicator()));
                          }
                          final product = _products[index];
                          final image = product['imageUrl'] as String? ?? '';
                          final stock = product['stockQuantity'] as int? ?? 0;
                          return Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: .045),
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              Container(
                                width: 48,
                                height: 48,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(9)),
                                child: image.isEmpty
                                    ? Icon(Icons.inventory_2_outlined,
                                        color: scheme.primary)
                                    : Image.network(image,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                            Icons.inventory_2_outlined,
                                            color: scheme.primary)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(product['name'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 3),
                                    Text(
                                        stock > 0
                                            ? '$stock in stock'
                                            : 'Out of stock',
                                        style: TextStyle(
                                            color: stock > 0
                                                ? scheme.onSurface
                                                    .withValues(alpha: .6)
                                                : scheme.error,
                                            fontSize: 11))
                                  ])),
                              const SizedBox(width: 6),
                              Text('₹${product['sellingPrice']}',
                                  style: TextStyle(
                                      color: scheme.secondary,
                                      fontWeight: FontWeight.w800))
                            ]),
                          );
                        }))
      ]),
    );
  }
}
