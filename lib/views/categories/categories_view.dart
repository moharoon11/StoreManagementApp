import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class CategoriesView extends StatefulWidget {
  const CategoriesView({Key? key}) : super(key: key);

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  bool _isLoading = true;
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(ApiConfig.categories);
      if (res['success'] == true) {
        setState(() {
          _categories = res['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showCategoryProductsModal(Map<String, dynamic> category) {
    List<dynamic> catProducts = [];
    bool loadingProducts = true;
    String search = '';

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
            void loadCatProducts() async {
              try {
                final res = await ApiService.get(
                  ApiConfig.products,
                  queryParameters: {
                    'categoryId': category['id'].toString(),
                    'pageSize': '100',
                  },
                );
                if (res['success'] == true) {
                  setModalState(() {
                    catProducts = res['data']['items'] ?? [];
                    loadingProducts = false;
                  });
                }
              } catch (_) {
                setModalState(() => loadingProducts = false);
              }
            }

            if (loadingProducts) {
              loadCatProducts();
            }

            final filtered = catProducts.where((p) {
              final name = (p['name'] as String).toLowerCase();
              return name.contains(search.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFEFF6FF),
                        backgroundImage: category['imageUrl'] != null && (category['imageUrl'] as String).isNotEmpty
                            ? NetworkImage(category['imageUrl'])
                            : null,
                        child: category['imageUrl'] == null || (category['imageUrl'] as String).isEmpty
                            ? const Icon(Icons.category, color: Color(0xFF2563EB), size: 20)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category['name'] ?? 'Category Products',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${catProducts.length} items in this category',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    onChanged: (val) => setModalState(() => search = val),
                    decoration: const InputDecoration(
                      hintText: 'Search products in category...',
                      prefixIcon: Icon(Icons.search, color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: loadingProducts
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                        : filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                                    SizedBox(height: 12),
                                    Text('No products in this category yet', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final p = filtered[index];
                                  final img = p['imageUrl'] as String?;
                                  final stock = p['stockQuantity'] as int;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                    color: const Color(0xFFF8FAFC),
                                    child: ListTile(
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                          image: img != null && img.isNotEmpty ? DecorationImage(image: NetworkImage(img), fit: BoxFit.cover) : null,
                                        ),
                                        child: img == null || img.isEmpty ? const Icon(Icons.inventory_2, color: Color(0xFF2563EB), size: 20) : null,
                                      ),
                                      title: Text(p['name'] ?? '', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                                      subtitle: Text('Stock: $stock', style: TextStyle(color: stock > 0 ? const Color(0xFF64748B) : const Color(0xFFEF4444), fontSize: 12)),
                                      trailing: Text('₹${p['sellingPrice']}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final nameController = TextEditingController(text: category?['name'] ?? '');
    String currentImageUrl = category?['imageUrl'] ?? '';
    bool isUploading = false;
    File? pickedImageFile;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
                if (image != null) {
                  setModalState(() {
                    pickedImageFile = File(image.path);
                    isUploading = true;
                  });

                  final uploadedUrl = await ApiService.uploadImage(image.path);
                  if (uploadedUrl != null) {
                    setModalState(() {
                      currentImageUrl = uploadedUrl;
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

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                category == null ? 'Add Category' : 'Edit Category',
                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
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
                                    pickImage(ImageSource.gallery);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
                                  title: const Text('Take a Photo'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    pickImage(ImageSource.camera);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          image: pickedImageFile != null
                              ? DecorationImage(image: FileImage(pickedImageFile!), fit: BoxFit.cover)
                              : (currentImageUrl.isNotEmpty
                                  ? DecorationImage(image: NetworkImage(currentImageUrl), fit: BoxFit.cover)
                                  : null),
                        ),
                        child: isUploading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                            : (pickedImageFile == null && currentImageUrl.isEmpty
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.add_a_photo, color: Color(0xFF2563EB), size: 28),
                                      SizedBox(height: 4),
                                      Text('Pick Image', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                    ],
                                  )
                                : null),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          Navigator.pop(ctx);
                          if (category == null) {
                            await ApiService.post(ApiConfig.categories, {
                              'name': name,
                              'imageUrl': currentImageUrl,
                            });
                          } else {
                            await ApiService.put('${ApiConfig.categories}/${category['id']}', {
                              'name': name,
                              'imageUrl': currentImageUrl,
                            });
                          }
                          _fetchCategories();
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCategory(int id) async {
    try {
      await ApiService.delete('${ApiConfig.categories}/$id');
      _fetchCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Product Categories',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _categories.isEmpty
                ? const Center(child: Text('No categories added yet.', style: TextStyle(color: Color(0xFF64748B))))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisExtent: 225,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final imageUrl = cat['imageUrl'] as String?;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _showCategoryProductsModal(cat),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFDBEAFE)),
                                          image: imageUrl != null && imageUrl.isNotEmpty
                                              ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: imageUrl == null || imageUrl.isEmpty
                                            ? const Icon(Icons.category_rounded, color: Color(0xFF2563EB), size: 22)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            InkWell(
                                              onTap: () => _showCategoryDialog(category: cat),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () => _deleteCategory(cat['id']),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF2F2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    cat['name'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: const [
                                      Text(
                                        'View products',
                                        style: TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF2563EB)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                          ),
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
