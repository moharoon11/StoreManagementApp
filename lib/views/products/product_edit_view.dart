import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../utils/quantity_utils.dart';

class ProductEditView extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<dynamic> categories;
  const ProductEditView(
      {Key? key, required this.product, required this.categories})
      : super(key: key);

  @override
  State<ProductEditView> createState() => _ProductEditViewState();
}

class _ProductEditViewState extends State<ProductEditView> {
  late TextEditingController _nameController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _stockController;

  int? _selectedCategory;
  late String _selectedUnit;
  String _productImageUrl = '';
  bool _isUploading = false;
  File? _pickedImageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.product['name']?.toString() ?? '');
    _costPriceController = TextEditingController(
        text: widget.product['costPrice']?.toString() ?? '');
    _sellingPriceController = TextEditingController(
        text: widget.product['sellingPrice']?.toString() ?? '');
    _stockController = TextEditingController(
        text: widget.product['stockQuantity']?.toString() ?? '');
    _selectedCategory = widget.product['categoryId'] as int?;
    _selectedUnit = productUnit(widget.product);
    _productImageUrl = widget.product['imageUrl']?.toString() ?? '';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          _pickedImageFile = File(image.path);
          _isUploading = true;
        });

        final url = await ApiService.uploadImage(image.path);
        if (url != null) {
          setState(() {
            _productImageUrl = url;
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Upload failed: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    }
  }

  Future<void> _updateProduct() async {
    if (_nameController.text.isEmpty || _sellingPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and Selling Price are required')));
      return;
    }

    setState(() => _isLoading = true);

    final body = {
      'name': _nameController.text.trim(),
      'costPrice': double.tryParse(_costPriceController.text) ?? 0.0,
      'sellingPrice': double.tryParse(_sellingPriceController.text) ?? 0.0,
      'stockQuantity': double.tryParse(_stockController.text) ?? 0,
      'unit': _selectedUnit,
      'imageUrl': _productImageUrl,
      if (_selectedCategory != null) 'categoryId': _selectedCategory!,
    };

    try {
      final res = await ApiService.put(
          '${ApiConfig.products}/${widget.product['id']}', body);
      if (res['success'] == true) {
        if (mounted) {
          Navigator.pop(
              context, true); // true to indicate success and need to refresh
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res['message'] ?? 'Failed to update')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", ""))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete Product'),
              content: const Text(
                  'Are you sure you want to delete this product? This action cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ));

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.delete(
          '${ApiConfig.products}/${widget.product['id']}');
      if (res['success'] == true) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res['message'] ?? 'Failed to delete')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", ""))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Edit Product',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteProduct,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                                  _pickImage(ImageSource.gallery);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.camera_alt,
                                    color: Color(0xFF365FF4)),
                                title: const Text('Take a Photo'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImage(ImageSource.camera);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD2D6E0)),
                      ),
                      child: _isUploading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF365FF4)))
                          : _pickedImageFile != null
                              ? Image.file(_pickedImageFile!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain)
                              : _productImageUrl.isNotEmpty
                                  ? Image.network(_productImageUrl,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const _ImagePlaceholder())
                                  : const _ImagePlaceholder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField('Product Name *', _nameController),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: widget.categories.map<DropdownMenuItem<int>>((cat) {
                    return DropdownMenuItem<int>(
                      value: cat['id'],
                      child: Text(cat['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            'Cost Price (₹)', _costPriceController,
                            isNumber: true)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildTextField(
                            'Selling Price (₹) *', _sellingPriceController,
                            isNumber: true)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                          'Stock Quantity *', _stockController,
                          isNumber: true),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: InputDecoration(
                          labelText: 'Unit *',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                        items: productUnits
                            .map((unit) => DropdownMenuItem(
                                value: unit, child: Text(unit)))
                            .toList(),
                        onChanged: (unit) =>
                            setState(() => _selectedUnit = unit!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        (_isUploading || _isLoading) ? null : _updateProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF365FF4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
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
