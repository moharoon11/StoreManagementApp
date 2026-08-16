import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

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
    String productImageUrl = '';
    bool isUploading = false;
    File? pickedImageFile;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Text('Add product',
                style: TextStyle(fontWeight: FontWeight.w800)),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(ctx)),
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
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Upload failed: ${e.toString().replaceAll("Exception: ", "")}')),
                    );
                  }
                }
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  top: 20,
                  left: 20,
                  right: 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Add New Product',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF172033))),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Color(0xFF6C7486)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => Container(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library,
                                          color: Color(0xFF365FF4)),
                                      title: const Text('Choose from Gallery'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        pickProductImage(ImageSource.gallery);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt,
                                          color: Color(0xFF365FF4)),
                                      title: const Text('Take a Photo'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        pickProductImage(ImageSource.camera);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            height: 156,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7FB),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFD2D6E0)),
                            ),
                            child: isUploading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF365FF4)))
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
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Color(0xFF172033)),
                        decoration:
                            const InputDecoration(labelText: 'Product Name *'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: createNewCategory,
                            onChanged: (val) {
                              setModalState(
                                  () => createNewCategory = val ?? false);
                            },
                            activeColor: const Color(0xFF365FF4),
                          ),
                          const Text('Create a new category inline',
                              style: TextStyle(
                                  color: Color(0xFF172033), fontSize: 13)),
                        ],
                      ),
                      if (createNewCategory) ...[
                        TextField(
                          controller: newCatController,
                          style: const TextStyle(color: Color(0xFF172033)),
                          decoration: const InputDecoration(
                              labelText: 'New Category Name *'),
                        ),
                      ] else ...[
                        DropdownButtonFormField<int>(
                          value: selectedCategory,
                          style: const TextStyle(color: Color(0xFF172033)),
                          decoration: const InputDecoration(
                              labelText: 'Select Category'),
                          items: _categories.map<DropdownMenuItem<int>>((cat) {
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
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: costPriceController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Color(0xFF172033)),
                              decoration: const InputDecoration(
                                  labelText: 'Cost Price (₹)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: sellingPriceController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Color(0xFF172033)),
                              decoration: const InputDecoration(
                                  labelText: 'Selling Price (₹) *'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFF172033)),
                        decoration: const InputDecoration(
                            labelText: 'Initial Stock Quantity *'),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  if (nameController.text.isEmpty ||
                                      sellingPriceController.text.isEmpty)
                                    return;

                                  final body = {
                                    'name': nameController.text.trim(),
                                    'costPrice': double.tryParse(
                                            costPriceController.text) ??
                                        0.0,
                                    'sellingPrice': double.tryParse(
                                            sellingPriceController.text) ??
                                        0.0,
                                    'stockQuantity':
                                        int.tryParse(stockController.text) ?? 0,
                                    'imageUrl': productImageUrl,
                                  };

                                  if (createNewCategory) {
                                    body['newCategoryName'] =
                                        newCatController.text.trim();
                                  } else {
                                    if (selectedCategory != null)
                                      body['categoryId'] = selectedCategory!;
                                  }

                                  Navigator.pop(ctx);
                                  await ApiService.post(
                                      ApiConfig.products, body);
                                  await _fetchCategories();
                                  await _fetchProducts();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF365FF4),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Create Product',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
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
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final catalogue = Column(children: [
        TextField(
            onChanged: (value) {
              _searchTerm = value;
              _fetchProducts();
            },
            decoration: const InputDecoration(
                hintText: 'Search your catalogue',
                prefixIcon: Icon(Icons.search_rounded))),
        const SizedBox(height: 16),
        Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(
                        child: Text('Nothing matches this selection.',
                            style: TextStyle(color: Color(0xFF6C7486))))
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: wide ? 260 : 190,
                            childAspectRatio: .78,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14),
                        itemCount: _products.length,
                        itemBuilder: (_, index) =>
                            _productCard(_products[index]))),
      ]);
      return Padding(
        padding: EdgeInsets.all(wide ? 20 : 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              children: [
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Catalogue',
                          style: TextStyle(
                              color: Color(0xFF172033),
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('Browse products by collection',
                          style:
                              TextStyle(color: Color(0xFF6C7486), fontSize: 12))
                    ]),
                ElevatedButton.icon(
                    onPressed: _showAddProductModal,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add product'))
              ]),
          const SizedBox(height: 16),
          Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          SizedBox(
                              width: 184, child: _categoryMenu(vertical: true)),
                          const SizedBox(width: 14),
                          Expanded(child: catalogue)
                        ])
                  : Column(children: [
                      SizedBox(
                          height: 48, child: _categoryMenu(vertical: false)),
                      const SizedBox(height: 16),
                      Expanded(child: catalogue)
                    ])),
        ]),
      );
    });
  }

  Widget _categoryMenu({required bool vertical}) {
    final items = <({String name, int? id, bool favourite, IconData icon})>[
      (
        name: 'All products',
        id: null,
        favourite: false,
        icon: Icons.apps_rounded
      ),
      (name: 'Favourites', id: null, favourite: true, icon: Icons.star_rounded),
      ..._categories.map((c) => (
            name: (c['name'] ?? 'Untitled').toString(),
            id: c['id'] as int?,
            favourite: false,
            icon: Icons.folder_outlined
          ))
    ];
    return ListView.separated(
        scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            vertical ? const SizedBox(height: 6) : const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = item.favourite
              ? _showFavouritesOnly
              : !item.favourite &&
                  !_showFavouritesOnly &&
                  _selectedCategoryId == item.id;
          return Material(
              color:
                  selected ? const Color(0xFFEEF0FF) : const Color(0xFFF6F7FB),
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = item.id;
                      _showFavouritesOnly = item.favourite;
                    });
                    _fetchProducts();
                  },
                  borderRadius: BorderRadius.circular(13),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(item.icon,
                            size: 18,
                            color: selected
                                ? const Color(0xFF365FF4)
                                : const Color(0xFF6C7486)),
                        const SizedBox(width: 8),
                        Text(item.name,
                            style: TextStyle(
                                color: selected
                                    ? const Color(0xFF365FF4)
                                    : const Color(0xFF172033),
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 12))
                      ]))));
        });
  }

  Widget _productCard(Map<String, dynamic> product) {
    final favourite =
        product['isFavourite'] == true || product['isFavourite'] == 1;
    final imageUrl = product['imageUrl'] as String? ?? '';
    final stock = product['stockQuantity'] as int? ?? 0;
    return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: Container(
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE6E8EF)),
                borderRadius: BorderRadius.circular(18)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Stack(children: [
                Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F8),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18)),
                        image: imageUrl.isEmpty
                            ? null
                            : DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover)),
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.inventory_2_outlined,
                            color: Color(0xFFA1A8B7), size: 36)
                        : null),
                Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                        onPressed: () =>
                            _toggleFavourite(product['id'], favourite),
                        style:
                            IconButton.styleFrom(backgroundColor: Colors.white),
                        icon: Icon(
                            favourite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: const Color(0xFFE4A331),
                            size: 19)))
              ])),
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product['categoryName'] ?? 'Uncategorised',
                            style: const TextStyle(
                                color: Color(0xFF365FF4),
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(product['name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF172033),
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('₹${product['sellingPrice']}',
                                  style: const TextStyle(
                                      color: Color(0xFF12A594),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                              Text('$stock in stock',
                                  style: TextStyle(
                                      color: stock <= 5
                                          ? const Color(0xFFE75C5C)
                                          : const Color(0xFF6C7486),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700))
                            ])
                      ]))
            ])));
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, color: Color(0xFF365FF4), size: 30),
          SizedBox(height: 4),
          Text('Upload Product Image',
              style: TextStyle(
                  color: Color(0xFF6C7486),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      );
}
