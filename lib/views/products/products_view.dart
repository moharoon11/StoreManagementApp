import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/ui_breakpoints.dart';
import '../../widgets/workspace_ui.dart';
import 'product_edit_view.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({Key? key}) : super(key: key);

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
      final queryParams = <String, String>{
        'pageNumber': '1',
        'pageSize': '50',
      };
      if (_searchTerm.isNotEmpty) queryParams['searchTerm'] = _searchTerm;
      if (_selectedCategoryId != null)
        queryParams['categoryId'] = _selectedCategoryId.toString();
      if (_showFavouritesOnly) queryParams['isFavourite'] = 'true';

      final res = await ApiService.get(ApiConfig.products,
          queryParameters: queryParams);
      if (res['success'] == true) {
        setState(() {
          _products = res['data']['items'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavourite(
      int productId, bool isCurrentlyFavourite) async {
    try {
      if (isCurrentlyFavourite) {
        await ApiService.delete('${ApiConfig.favourites}/$productId');
      } else {
        await ApiService.post('${ApiConfig.favourites}/$productId', {});
      }
      _fetchProducts();
    } catch (_) {}
  }

  void _showAddProductModal() {
    final nameController = TextEditingController();
    final costPriceController = TextEditingController();
    final sellingPriceController = TextEditingController();
    final stockController = TextEditingController(text: '10');
    final newCatController = TextEditingController();

    int? selectedCategory =
        _categories.isNotEmpty ? _categories.first['id'] : null;
    bool createNewCategory = false;
    String selectedUnit = 'Piece';
    String productImageUrl = '';
    bool isUploading = false;
    File? pickedImageFile;

    void showSourceSheet(BuildContext sheetContext,
        Future<void> Function(ImageSource) maybePick) {
      showModalBottomSheet(
        context: sheetContext,
        builder: (_) => SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                maybePick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                maybePick(ImageSource.camera);
              },
            ),
          ]),
        ),
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: const Text('Add product',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          body: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickProductImage(ImageSource source) async {
                try {
                  final picker = ImagePicker();
                  final XFile? image =
                      await picker.pickImage(source: source, imageQuality: 80);
                  if (image != null) {
                    setModalState(() {
                      pickedImageFile = File(image.path);
                      isUploading = true;
                    });
                    final url = await ApiService.uploadImage(image.path);
                    if (url != null) {
                      setModalState(() {
                        productImageUrl = url;
                        isUploading = false;
                      });
                    }
                  }
                } catch (e) {
                  setModalState(() => isUploading = false);
                }
              }

              return SingleChildScrollView(
                padding: Ui.pagePadding(context),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SurfacePanel(
                      accent: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const LedgerKicker('Details'),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () =>
                                showSourceSheet(context, pickProductImage),
                            child: Container(
                              height: 156,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: .45),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant),
                              ),
                              child: isUploading
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : pickedImageFile != null
                                      ? Image.file(pickedImageFile!,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.contain)
                                      : productImageUrl.isNotEmpty
                                          ? Image.network(productImageUrl,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  const _ImagePlaceholder())
                                          : const _ImagePlaceholder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: nameController,
                            style: const TextStyle(fontSize: 14),
                            decoration:
                                const InputDecoration(labelText: 'Product name *'),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Checkbox(
                              value: createNewCategory,
                              onChanged: (val) {
                                setModalState(
                                    () => createNewCategory = val ?? false);
                              },
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                            const Expanded(
                              child: Text('Create a new category',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ]),
                          if (createNewCategory) ...[
                            TextField(
                              controller: newCatController,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                  labelText: 'New category name *'),
                            ),
                          ] else ...[
                            DropdownButtonFormField<int>(
                              value: selectedCategory,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                  labelText: 'Select category'),
                              items:
                                  _categories.map<DropdownMenuItem<int>>((cat) {
                                return DropdownMenuItem<int>(
                                  value: cat['id'],
                                  child: Text(cat['name'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setModalState(() => selectedCategory = val),
                            ),
                          ],
                          const SizedBox(height: 12),
                          LayoutBuilder(builder: (context, constraints) {
                            final pair = constraints.maxWidth >= 420;
                            final cost = TextField(
                              controller: costPriceController,
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 14),
                              decoration:
                                  const InputDecoration(labelText: 'Cost price (₹)'),
                            );
                            final sell = TextField(
                              controller: sellingPriceController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                  labelText: 'Selling price (₹) *'),
                            );
                            if (pair) {
                              return Row(children: [
                                Expanded(child: cost),
                                const SizedBox(width: 12),
                                Expanded(child: sell),
                              ]);
                            }
                            return Column(children: [
                              cost,
                              const SizedBox(height: 10),
                              sell,
                            ]);
                          }),
                          const SizedBox(height: 12),
                          LayoutBuilder(builder: (context, constraints) {
                            final pair = constraints.maxWidth >= 420;
                            final stock = TextField(
                              controller: stockController,
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                  labelText: 'Initial stock *'),
                            );
                            final unit = DropdownButtonFormField<String>(
                              value: selectedUnit,
                              style: const TextStyle(fontSize: 14),
                              decoration:
                                  const InputDecoration(labelText: 'Unit *'),
                              items: productUnits
                                  .map((unit) => DropdownMenuItem(
                                      value: unit, child: Text(unit)))
                                  .toList(),
                              onChanged: (unit) =>
                                  setModalState(() => selectedUnit = unit!),
                            );
                            if (pair) {
                              return Row(children: [
                                Expanded(child: stock),
                                const SizedBox(width: 12),
                                Expanded(child: unit),
                              ]);
                            }
                            return Column(children: [
                              stock,
                              const SizedBox(height: 10),
                              unit,
                            ]);
                          }),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: isUploading
                                  ? null
                                  : () async {
                                      if (nameController.text.isEmpty ||
                                          sellingPriceController.text.isEmpty) {
                                        return;
                                      }
                                      final body = {
                                        'name': nameController.text.trim(),
                                        'costPrice': double.tryParse(
                                                costPriceController.text) ??
                                            0.0,
                                        'sellingPrice': double.tryParse(
                                                sellingPriceController.text) ??
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
                                      } else {
                                        if (selectedCategory != null) {
                                          body['categoryId'] = selectedCategory!;
                                        }
                                      }
                                      Navigator.pop(ctx);
                                      await ApiService.post(
                                          ApiConfig.products, body);
                                      await _fetchCategories();
                                      await _fetchProducts();
                                    },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Create product'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return WorkspacePage(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageIntro(
          eyebrow: 'Product catalogue',
          title: 'Products',
          description: 'Browse and manage everything you sell.',
          action: FilledButton.icon(
            onPressed: _showAddProductModal,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add product'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final catalogue = Column(children: [
              SizedBox(
                height: 44,
                child: TextField(
                  onChanged: (value) {
                    _searchTerm = value;
                    _fetchProducts();
                  },
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search your catalogue',
                    hintStyle: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .45)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _products.isEmpty
                        ? const EmptyCanvas(
                            icon: Icons.inventory_2_outlined,
                            title: 'Nothing matches this selection',
                            detail:
                                'Try a different search or category filter.',
                          )
                        : GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: wide ? 220 : 165,
                              childAspectRatio: .82,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (_, index) =>
                                _productCard(_products[index]),
                          ),
              ),
            ]);
            return wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                        width: 168, child: _categoryMenu(vertical: true)),
                    const SizedBox(width: 10),
                    Expanded(child: catalogue),
                  ])
                : Column(children: [
                    SizedBox(
                        height: 40, child: _categoryMenu(vertical: false)),
                    const SizedBox(height: 10),
                    Expanded(child: catalogue),
                  ]);
          }),
        ),
      ]),
    );
  }

  Widget _categoryMenu({required bool vertical}) {
    final items = <({String name, int? id, bool favourite, IconData icon})>[
      (
        name: 'All products',
        id: null,
        favourite: false,
        icon: Icons.apps_rounded
      ),
      (
        name: 'Favourites',
        id: null,
        favourite: true,
        icon: Icons.star_rounded
      ),
      ..._categories.map((c) => (
            name: (c['name'] ?? 'Untitled').toString(),
            id: c['id'] as int?,
            favourite: false,
            icon: Icons.folder_outlined
          )),
    ];
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          vertical ? const SizedBox(height: 6) : const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = item.favourite
            ? _showFavouritesOnly
            : _selectedCategoryId == item.id;
        return InkWell(
          onTap: () {
            setState(() {
              _showFavouritesOnly = item.favourite;
              _selectedCategoryId = item.favourite ? null : item.id;
            });
            _fetchProducts();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: .1)
                  : Colors.transparent,
              border: Border.all(
                  color:
                      selected ? scheme.primary : scheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(item.icon,
                  size: 17,
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: .55)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: selected ? scheme.primary : scheme.onSurface,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12)),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final scheme = Theme.of(context).colorScheme;
    final favourite =
        product['isFavourite'] == true || product['isFavourite'] == 1;
    final imageUrl = product['imageUrl'] as String? ?? '';
    final stock = quantityValue(product['stockQuantity']);

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () async {
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
        },
        borderRadius: BorderRadius.circular(9),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(9)),
                      child: Container(
                        width: double.infinity,
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: .5),
                        child: imageUrl.isEmpty
                            ? Icon(Icons.inventory_2_outlined,
                                size: 30,
                                color:
                                    scheme.onSurface.withValues(alpha: .35))
                            : Image.network(imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.inventory_2_outlined,
                                    size: 30,
                                    color: scheme.onSurface
                                        .withValues(alpha: .35))),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Material(
                      color: scheme.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      child: InkWell(
                        onTap: () =>
                            _toggleFavourite(product['id'], favourite),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            favourite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: const Color(0xFFB7791F),
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['categoryName'] ?? 'Uncategorised',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.primary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .3)),
                    const SizedBox(height: 2),
                    Text(product['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                    const SizedBox(height: 7),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('₹${product['sellingPrice']}',
                              style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900)),
                          Text(
                              '${formatProductQuantity(stock, product)} in stock',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: stock <= 5
                                      ? scheme.error
                                      : scheme.onSurface
                                          .withValues(alpha: .55),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ]),
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

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined,
            color: scheme.onSurface.withValues(alpha: .35), size: 30),
        const SizedBox(height: 4),
        Text('Upload product image',
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .5),
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}