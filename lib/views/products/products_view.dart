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
import '../../widgets/workspace_ui.dart';
import 'product_edit_view.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  bool _isLoading = true;
  List<dynamic> _products = [];
  List<dynamic> _categories = [];

  String _searchTerm = '';
  int? _selectedCategoryId;
  bool _showFavouritesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchCategories();
    await _fetchProducts();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await ApiService.get(ApiConfig.categories);
      if (res['success'] == true) {
        _categories = res['data'] ?? [];
      }
    } catch (_) {}
  }

  Future<void> _fetchProducts() async {
    try {
      // The server's unfiltered catalogue response is inconsistent in the
      // deployed API, while category-scoped results are reliable (as seen on
      // the Categories page). Build the All-products view from those reliable
      // category pages instead.
      if (_selectedCategoryId == null && _categories.isNotEmpty) {
        final items = await _fetchProductsForCategories();
        if (mounted) {
          setState(() {
            _products = items;
            _isLoading = false;
          });
        }
        return;
      }
      final queryParams = <String, String>{
        'pageNumber': '1',
        // The live endpoint caps catalogue pages at 30; using 50 made this
        // screen silently receive no usable page while Categories (30) worked.
        'pageSize': '30',
      };
      if (_searchTerm.isNotEmpty) {
        queryParams['searchTerm'] = _searchTerm;
      }
      if (_selectedCategoryId != null) {
        queryParams['categoryId'] = _selectedCategoryId.toString();
      }
      final res = await ApiService.get(
        ApiConfig.products,
        queryParameters: queryParams,
      );
      if (mounted) {
        setState(() {
          _products = _extractProductItems(res);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<dynamic>> _fetchProductsForCategories() async {
    final pages = await Future.wait(_categories.map((item) async {
      final category = Map<String, dynamic>.from(item as Map);
      try {
        final res = await ApiService.get(ApiConfig.products, queryParameters: {
          'categoryId': category['id'].toString(),
          'pageNumber': '1',
          'pageSize': '30',
          if (_searchTerm.isNotEmpty) 'searchTerm': _searchTerm,
        });
        return _extractProductItems(res);
      } catch (_) {
        return const <dynamic>[];
      }
    }));
    final seenIds = <dynamic>{};
    return [
      for (final product in pages.expand((page) => page))
        if (seenIds.add(Map<String, dynamic>.from(product as Map)['id']))
          product,
    ];
  }

  /// The deployed catalogue endpoint can return a paged `data.items` value,
  /// a list in `data`, or a top-level list.  Categories already accepts the
  /// paged form; accepting all valid forms keeps Products populated too.
  List<dynamic> _extractProductItems(dynamic response) {
    if (response is List) return List<dynamic>.from(response);
    if (response is! Map) return const [];
    final data = response['data'];
    if (data is List) return List<dynamic>.from(data);
    if (data is Map) {
      final items = data['items'] ?? data['products'] ?? data['rows'];
      if (items is List) return List<dynamic>.from(items);
    }
    final items = response['items'] ?? response['products'];
    return items is List ? List<dynamic>.from(items) : const [];
  }

  void _showAddProductModal() {
    final nameController = TextEditingController();
    final costPriceController = TextEditingController();
    final sellingPriceController = TextEditingController();
    final stockController = TextEditingController(text: '10');
    final newCatController = TextEditingController();

    int? selectedCategory =
        _categories.isNotEmpty ? _categories.first['id'] as int? : null;
    bool createNewCategory = false;
    String selectedUnit = 'Piece';
    String productImageUrl = '';
    bool isUploading = false;
    XFile? pickedImageFile;

    final addProductRoute = MaterialPageRoute<void>(
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickProductImage() async {
            try {
              final image = await AdaptiveImageService.pickForUser(
                context,
                sheetTitle: 'Add product image',
                galleryLabel: 'Choose product image',
              );
              if (image == null) return;

              setModalState(() {
                pickedImageFile = image;
                isUploading = true;
              });

              final url = await ApiService.uploadImage(image);
              if (url != null) {
                setModalState(() {
                  productImageUrl = url;
                  isUploading = false;
                });
              } else {
                setModalState(() => isUploading = false);
              }
            } catch (e) {
              setModalState(() => isUploading = false);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Upload failed: ${e.toString().replaceAll("Exception: ", "")}',
                  ),
                ),
              );
            }
          }

          Widget buildPair(Widget first, Widget second) {
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 520) {
                  return Column(
                    children: [
                      first,
                      const SizedBox(height: 12),
                      second,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: first),
                    const SizedBox(width: 12),
                    Expanded(child: second),
                  ],
                );
              },
            );
          }

          final scheme = Theme.of(context).colorScheme;
          final wide = MediaQuery.sizeOf(context).width >= 860;

          Widget imagePicker() => GestureDetector(
                onTap: pickProductImage,
                child: Container(
                  width: double.infinity,
                  height: 206,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: .26,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: isUploading
                      ? const Center(child: CircularProgressIndicator())
                      : AdaptiveImagePreview(
                          pickedImage: pickedImageFile,
                          imageUrl: productImageUrl,
                          fit: BoxFit.cover,
                          placeholder: const _ImagePlaceholder(),
                        ),
                ),
              );

          Widget formFields() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    onChanged: (_) => setModalState(() {}),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Product name *',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: .18,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: createNewCategory,
                          onChanged: (value) {
                            setModalState(
                              () => createNewCategory = value ?? false,
                            );
                          },
                        ),
                        const Expanded(
                          child: Text('Create a new category inline'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (createNewCategory)
                    TextField(
                      controller: newCatController,
                      decoration: const InputDecoration(
                        labelText: 'New category name *',
                      ),
                    )
                  else
                    DropdownButtonFormField<int>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Select category',
                      ),
                      items: _categories.map<DropdownMenuItem<int>>((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['id'],
                          child: Text((cat['name'] ?? '').toString()),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setModalState(() => selectedCategory = value),
                    ),
                  const SizedBox(height: 12),
                  buildPair(
                    TextField(
                      controller: costPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cost price (₹)',
                      ),
                    ),
                    TextField(
                      controller: sellingPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Selling price (₹) *',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  buildPair(
                    TextField(
                      controller: stockController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Initial stock quantity *',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unit *'),
                      items: productUnits
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      onChanged: (unit) {
                        if (unit == null) return;
                        setModalState(() => selectedUnit = unit);
                      },
                    ),
                  ),
                ],
              );

          return Scaffold(
            appBar: AppBar(
              title: const Text('Add product'),
            ),
            body: WorkspacePage(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: SurfacePanel(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: imagePicker()),
                                const SizedBox(width: 16),
                                Expanded(child: formFields()),
                              ],
                            )
                          : Column(
                              children: [
                                imagePicker(),
                                const SizedBox(height: 16),
                                formFields(),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SurfacePanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 520;
                      final summary = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'New catalogue item',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: scheme.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nameController.text.trim().isEmpty
                                ? 'Waiting for product details'
                                : nameController.text.trim(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      );

                      final action = SizedBox(
                        width: narrow ? double.infinity : 220,
                        child: FilledButton(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  if (nameController.text.trim().isEmpty ||
                                      sellingPriceController.text
                                          .trim()
                                          .isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Product name and selling price are required.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final body = <String, dynamic>{
                                    'name': nameController.text.trim(),
                                    'costPrice': double.tryParse(
                                          costPriceController.text,
                                        ) ??
                                        0.0,
                                    'sellingPrice': double.tryParse(
                                          sellingPriceController.text,
                                        ) ??
                                        0.0,
                                    'stockQuantity':
                                        double.tryParse(stockController.text) ??
                                            0,
                                    'unit': selectedUnit,
                                    'imageUrl': productImageUrl,
                                  };

                                  if (createNewCategory) {
                                    body['newCategoryName'] =
                                        newCatController.text.trim();
                                  } else if (selectedCategory != null) {
                                    body['categoryId'] = selectedCategory!;
                                  }

                                  Navigator.pop(ctx);
                                  await ApiService.post(
                                    ApiConfig.products,
                                    body,
                                  );
                                  await _fetchCategories();
                                  await _fetchProducts();
                                },
                          child: Text(
                            isUploading
                                ? 'Uploading image...'
                                : 'Create product',
                          ),
                        ),
                      );

                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            summary,
                            const SizedBox(height: 12),
                            action,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: summary),
                          const SizedBox(width: 16),
                          action,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    Navigator.of(context).push(addProductRoute);
    // Do not dispose controllers while the route's exit animation still owns
    // TextFields that depend on them. That was the source of the framework
    // `_dependents.isEmpty` assertion even though the API saved the product.
    addProductRoute.completed.whenComplete(() {
      nameController.dispose();
      costPriceController.dispose();
      sellingPriceController.dispose();
      stockController.dispose();
      newCatController.dispose();
    });
  }

  List<dynamic> _visibleProducts(AppProvider provider) {
    if (!_showFavouritesOnly) return _products;
    return _products.where((product) {
      final map = Map<String, dynamic>.from(product as Map);
      return provider.isFavourite(map['id'] as int);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final provider = context.watch<AppProvider>();
    final visibleProducts = _visibleProducts(provider);
    return WorkspacePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(
            eyebrow: 'Products',
            title: 'Catalogue management',
            description:
                'A new browsing layout with a proper filter panel, safer card widths, and faster access to edit and favourite actions.',
            action: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadInitialData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
                FilledButton.icon(
                  onPressed: _showAddProductModal,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add product'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (compact) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  label: '${_products.length} products',
                  color: Theme.of(context).colorScheme.primary,
                ),
                StatusPill(
                  label: '${_categories.length} categories',
                  color: Theme.of(context).colorScheme.secondary,
                ),
                StatusPill(
                  label: '${provider.favouriteProductIds.length} favourites',
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else ...[
            AdaptiveWrapGrid(
              minItemWidth: 180,
              children: [
                StatTile(
                  label: 'Visible products',
                  value: '${_products.length}',
                  icon: Icons.inventory_2_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                StatTile(
                  label: 'Categories',
                  value: '${_categories.length}',
                  icon: Icons.account_tree_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                StatTile(
                  label: 'Favourites',
                  value: '${provider.favouriteProductIds.length}',
                  icon: Icons.star_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 268,
                            child: _CatalogueFilters(
                              categories: _categories,
                              selectedCategoryId: _selectedCategoryId,
                              showFavouritesOnly: _showFavouritesOnly,
                              onSelectAll: () {
                                setState(() {
                                  _selectedCategoryId = null;
                                  _showFavouritesOnly = false;
                                });
                                _fetchProducts();
                              },
                              onSelectFavourites: () {
                                setState(() {
                                  _selectedCategoryId = null;
                                  _showFavouritesOnly = true;
                                });
                                _fetchProducts();
                              },
                              onSelectCategory: (id) {
                                setState(() {
                                  _selectedCategoryId = id;
                                  _showFavouritesOnly = false;
                                });
                                _fetchProducts();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _ProductGridPanel(
                              isLoading: _isLoading,
                              products: visibleProducts,
                              searchTerm: _searchTerm,
                              onSearchChanged: (value) {
                                _searchTerm = value;
                                _fetchProducts();
                              },
                              onEditProduct: _openProductEditor,
                              onToggleFavourite: provider.toggleFavourite,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 40,
                            child: _FilterStrip(
                              categories: _categories,
                              selectedCategoryId: _selectedCategoryId,
                              showFavouritesOnly: _showFavouritesOnly,
                              onSelectAll: () {
                                setState(() {
                                  _selectedCategoryId = null;
                                  _showFavouritesOnly = false;
                                });
                                _fetchProducts();
                              },
                              onSelectFavourites: () {
                                setState(() {
                                  _selectedCategoryId = null;
                                  _showFavouritesOnly = true;
                                });
                                _fetchProducts();
                              },
                              onSelectCategory: (id) {
                                setState(() {
                                  _selectedCategoryId = id;
                                  _showFavouritesOnly = false;
                                });
                                _fetchProducts();
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: _ProductGridPanel(
                              isLoading: _isLoading,
                              products: visibleProducts,
                              searchTerm: _searchTerm,
                              onSearchChanged: (value) {
                                _searchTerm = value;
                                _fetchProducts();
                              },
                              onEditProduct: _openProductEditor,
                              onToggleFavourite: provider.toggleFavourite,
                            ),
                          ),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProductEditor(Map<String, dynamic> product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEditView(
          product: product,
          categories: _categories,
        ),
      ),
    );
    if (result == true) {
      _fetchProducts();
    }
  }
}

class _CatalogueFilters extends StatelessWidget {
  const _CatalogueFilters({
    required this.categories,
    required this.selectedCategoryId,
    required this.showFavouritesOnly,
    required this.onSelectAll,
    required this.onSelectFavourites,
    required this.onSelectCategory,
  });

  final List<dynamic> categories;
  final int? selectedCategoryId;
  final bool showFavouritesOnly;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectFavourites;
  final ValueChanged<int?> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Browse catalogue',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Switch between all products, favourites, or a single category.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: .62),
                ),
          ),
          const SizedBox(height: 18),
          _FilterTile(
            label: 'All products',
            icon: Icons.apps_rounded,
            selected: !showFavouritesOnly && selectedCategoryId == null,
            onTap: onSelectAll,
          ),
          const SizedBox(height: 10),
          _FilterTile(
            label: 'Favourites',
            icon: Icons.star_rounded,
            selected: showFavouritesOnly,
            onTap: onSelectFavourites,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _FilterTile(
                  label: (category['name'] ?? 'Untitled').toString(),
                  icon: Icons.folder_outlined,
                  selected: !showFavouritesOnly &&
                      selectedCategoryId == category['id'],
                  onTap: () => onSelectCategory(category['id'] as int?),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.categories,
    required this.selectedCategoryId,
    required this.showFavouritesOnly,
    required this.onSelectAll,
    required this.onSelectFavourites,
    required this.onSelectCategory,
  });

  final List<dynamic> categories;
  final int? selectedCategoryId;
  final bool showFavouritesOnly;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectFavourites;
  final ValueChanged<int?> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _StripChip(
          label: 'All',
          selected: !showFavouritesOnly && selectedCategoryId == null,
          onTap: onSelectAll,
        ),
        const SizedBox(width: 8),
        _StripChip(
          label: 'Favourites',
          selected: showFavouritesOnly,
          onTap: onSelectFavourites,
        ),
        const SizedBox(width: 8),
        for (final category in categories) ...[
          _StripChip(
            label: (category['name'] ?? 'Untitled').toString(),
            selected:
                !showFavouritesOnly && selectedCategoryId == category['id'],
            onTap: () => onSelectCategory(category['id'] as int?),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ProductGridPanel extends StatelessWidget {
  const _ProductGridPanel({
    required this.isLoading,
    required this.products,
    required this.searchTerm,
    required this.onSearchChanged,
    required this.onEditProduct,
    required this.onToggleFavourite,
  });

  final bool isLoading;
  final List<dynamic> products;
  final String searchTerm;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Map<String, dynamic>> onEditProduct;
  final ValueChanged<int> onToggleFavourite;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final phone = constraints.maxWidth < 460;
          final columns = phone
              ? 1
              : math.max(
                  1,
                  (constraints.maxWidth / 228).floor(),
                );
          final useList = phone;
          final cardExtent = columns == 1 && !useList
              ? 166.0
              : phone
                  ? 222.0
                  : 312.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: constraints.maxWidth < 420 ? constraints.maxWidth : 340,
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search your catalogue',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchTerm.isEmpty
                        ? null
                        : const Icon(Icons.tune_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : products.isEmpty
                        ? const EmptyCanvas(
                            icon: Icons.inventory_2_outlined,
                            title: 'No matching products',
                            detail: 'Try another category or search term.',
                          )
                        : useList
                            ? ListView.separated(
                                itemCount: products.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, index) => _ProductCard(
                                  product: Map<String, dynamic>.from(
                                      products[index] as Map),
                                  compact: true,
                                  onEditProduct: onEditProduct,
                                  onToggleFavourite: onToggleFavourite,
                                ),
                              )
                            : GridView.builder(
                                itemCount: products.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  mainAxisExtent: cardExtent,
                                ),
                                itemBuilder: (_, index) => _ProductCard(
                                  product: Map<String, dynamic>.from(
                                      products[index] as Map),
                                  compact: columns == 1,
                                  dense: phone,
                                  onEditProduct: onEditProduct,
                                  onToggleFavourite: onToggleFavourite,
                                ),
                              ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.compact,
    this.dense = false,
    required this.onEditProduct,
    required this.onToggleFavourite,
  });

  final Map<String, dynamic> product;
  final bool compact;
  final bool dense;
  final ValueChanged<Map<String, dynamic>> onEditProduct;
  final ValueChanged<int> onToggleFavourite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final favourite =
        context.watch<AppProvider>().isFavourite(product['id'] as int);
    final imageUrl = (product['imageUrl'] ?? '').toString();
    final stock = quantityValue(product['stockQuantity']);

    if (compact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onEditProduct(product),
          borderRadius: BorderRadius.circular(24),
          child: SurfacePanel(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _ProductArtwork(imageUrl: imageUrl, compact: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (product['name'] ?? '').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                onToggleFavourite(product['id'] as int),
                            icon: Icon(
                              favourite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: scheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        (product['categoryName'] ?? 'Uncategorised').toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${product['sellingPrice']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      StatusPill(
                        label:
                            '${formatProductQuantity(stock, product)} in stock',
                        color: stock <= 5 ? scheme.error : scheme.secondary,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onEditProduct(product),
        borderRadius: BorderRadius.circular(24),
        child: SurfacePanel(
          padding: EdgeInsets.all(dense ? 10 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _ProductArtwork(imageUrl: imageUrl, dense: dense),
                  Positioned(
                    top: dense ? 6 : 8,
                    right: dense ? 6 : 8,
                    child: IconButton(
                      onPressed: () => onToggleFavourite(product['id'] as int),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        minimumSize: Size.square(dense ? 34 : 40),
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(
                        favourite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: scheme.tertiary,
                        size: dense ? 18 : 22,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: dense ? 10 : 14),
              Text(
                (product['categoryName'] ?? 'Uncategorised').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: dense ? .7 : 1.1,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                (product['name'] ?? '').toString(),
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
              Text(
                '₹${product['sellingPrice']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (dense
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.headlineSmall)
                    ?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: dense ? 6 : 10),
              if (dense)
                Text(
                  '${formatProductQuantity(stock, product)} in stock',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: stock <= 5 ? scheme.error : scheme.secondary,
                      ),
                )
              else
                StatusPill(
                  label: '${formatProductQuantity(stock, product)} in stock',
                  color: stock <= 5 ? scheme.error : scheme.secondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductArtwork extends StatelessWidget {
  const _ProductArtwork({
    required this.imageUrl,
    this.compact = false,
    this.dense = false,
  });

  final String imageUrl;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: compact ? 88 : double.infinity,
      height: compact
          ? 104
          : dense
              ? 88
              : 126,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .26),
        borderRadius: BorderRadius.circular(dense ? 18 : 24),
      ),
      child: imageUrl.isEmpty
          ? Icon(
              Icons.inventory_2_outlined,
              color: scheme.onSurface.withValues(alpha: .34),
              size: compact
                  ? 32
                  : dense
                      ? 30
                      : 42,
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.inventory_2_outlined,
                color: scheme.onSurface.withValues(alpha: .34),
                size: compact
                    ? 32
                    : dense
                        ? 30
                        : 42,
              ),
            ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: .14)
                : scheme.surfaceContainerHighest.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: .64),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripChip extends StatelessWidget {
  const _StripChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: .14) : scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            color: scheme.primary, size: 34),
        const SizedBox(height: 8),
        Text(
          'Upload product image',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: .62),
              ),
        ),
      ],
    );
  }
}
