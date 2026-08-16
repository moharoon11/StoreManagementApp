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
      if (_selectedCategoryId != null) queryParams['categoryId'] = _selectedCategoryId.toString();
      if (_showFavouritesOnly) queryParams['isFavourite'] = 'true';

      final res = await ApiService.get(ApiConfig.products, queryParameters: queryParams);
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

  Future<void> _toggleFavourite(int productId, bool isCurrentlyFavourite) async {
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

    int? selectedCategory = _categories.isNotEmpty ? _categories.first['id'] : null;
    bool createNewCategory = false;
    String productImageUrl = '';
    bool isUploading = false;
    File? pickedImageFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickProductImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
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
                    SnackBar(content: Text('Upload failed: ${e.toString().replaceAll("Exception: ", "")}')),
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
                        const Text('Add New Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF64748B)),
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
                                    leading: const Icon(Icons.photo_library, color: Color(0xFF2563EB)),
                                    title: const Text('Choose from Gallery'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      pickProductImage(ImageSource.gallery);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
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
                          height: 110,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            image: pickedImageFile != null
                                ? DecorationImage(image: FileImage(pickedImageFile!), fit: BoxFit.cover)
                                : (productImageUrl.isNotEmpty
                                    ? DecorationImage(image: NetworkImage(productImageUrl), fit: BoxFit.cover)
                                    : null),
                          ),
                          child: isUploading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                              : (pickedImageFile == null && productImageUrl.isEmpty
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.add_a_photo, color: Color(0xFF2563EB), size: 30),
                                        SizedBox(height: 4),
                                        Text('Upload Product Image', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                                      ],
                                    )
                                  : null),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(labelText: 'Product Name *'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: createNewCategory,
                          onChanged: (val) {
                            setModalState(() => createNewCategory = val ?? false);
                          },
                          activeColor: const Color(0xFF2563EB),
                        ),
                        const Text('Create a new category inline', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13)),
                      ],
                    ),
                    if (createNewCategory) ...[
                      TextField(
                        controller: newCatController,
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(labelText: 'New Category Name *'),
                      ),
                    ] else ...[
                      DropdownButtonFormField<int>(
                        value: selectedCategory,
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(labelText: 'Select Category'),
                        items: _categories.map<DropdownMenuItem<int>>((cat) {
                          return DropdownMenuItem<int>(
                            value: cat['id'],
                            child: Text(cat['name'] ?? ''),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedCategory = val),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costPriceController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(labelText: 'Cost Price (₹)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: sellingPriceController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(labelText: 'Selling Price (₹) *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(labelText: 'Initial Stock Quantity *'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isUploading
                            ? null
                            : () async {
                                if (nameController.text.isEmpty || sellingPriceController.text.isEmpty) return;

                                final body = {
                                  'name': nameController.text.trim(),
                                  'costPrice': double.tryParse(costPriceController.text) ?? 0.0,
                                  'sellingPrice': double.tryParse(sellingPriceController.text) ?? 0.0,
                                  'stockQuantity': int.tryParse(stockController.text) ?? 0,
                                  'imageUrl': productImageUrl,
                                };

                                if (createNewCategory) {
                                  body['newCategoryName'] = newCatController.text.trim();
                                } else {
                                  if (selectedCategory != null) body['categoryId'] = selectedCategory!;
                                }

                                Navigator.pop(ctx);
                                await ApiService.post(ApiConfig.products, body);
                                await _fetchCategories();
                                await _fetchProducts();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Create Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Products Catalog',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddProductModal,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  onChanged: (val) {
                    _searchTerm = val;
                    _fetchProducts();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search products by name...',
                    prefixIcon: Icon(Icons.search, color: Color(0xFF2563EB)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Favourites', style: TextStyle(fontSize: 12)),
                selected: _showFavouritesOnly,
                selectedColor: const Color(0xFFFEF3C7),
                checkmarkColor: const Color(0xFFD97706),
                onSelected: (selected) {
                  setState(() => _showFavouritesOnly = selected);
                  _fetchProducts();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _products.isEmpty
                    ? const Center(child: Text('No products found.', style: TextStyle(color: Color(0xFF64748B))))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final p = _products[index];
                          final isFav = p['isFavourite'] == 1 || p['isFavourite'] == true;
                          final imageUrl = p['imageUrl'] as String?;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      height: 120,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                        color: const Color(0xFFF1F5F9),
                                        image: imageUrl != null && imageUrl.isNotEmpty
                                            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: imageUrl == null || imageUrl.isEmpty
                                          ? const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 36)
                                          : null,
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.white.withOpacity(0.9),
                                        radius: 16,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(isFav ? Icons.star : Icons.star_border, color: const Color(0xFFF59E0B), size: 18),
                                          onPressed: () => _toggleFavourite(p['id'], isFav),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['categoryName'] ?? '',
                                        style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        p['name'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₹${p['sellingPrice']}',
                                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (p['stockQuantity'] as int) <= 5 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Qty: ${p['stockQuantity']}',
                                              style: TextStyle(
                                                color: (p['stockQuantity'] as int) <= 5 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
