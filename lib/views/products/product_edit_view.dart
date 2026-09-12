import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/ui_breakpoints.dart';
import '../../widgets/workspace_ui.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    super.dispose();
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
          Navigator.pop(context, true);
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
        title: const Text('Delete product'),
        content: const Text(
            'Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFB42318)))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res =
          await ApiService.delete('${ApiConfig.products}/${widget.product['id']}');
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

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text('Edit product',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Delete product',
            icon: Icon(Icons.delete_outline, color: scheme.error),
            onPressed: _deleteProduct,
          ),
        ],
      ),
      body: Stack(children: [
        SingleChildScrollView(
          padding: Ui.pagePadding(context),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: _buildFormBody(scheme),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: scheme.scrim.withValues(alpha: .28),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ]),
    );
  }

  Widget _buildFormBody(ColorScheme scheme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GestureDetector(
        onTap: _showImageSourceSheet,
        child: Container(
          height: 190,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: _isUploading
              ? const Center(child: CircularProgressIndicator())
              : _pickedImageFile != null
                  ? Image.file(_pickedImageFile!,
                      fit: BoxFit.contain, width: double.infinity)
                  : _productImageUrl.isNotEmpty
                      ? Image.network(_productImageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              const _ImagePlaceholder())
                      : const _ImagePlaceholder(),
        ),
      ),
      const SizedBox(height: 16),
      SurfacePanel(
        accent: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const LedgerKicker('Details'),
          const SizedBox(height: 10),
          _buildTextField('Product name *', _nameController),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
            items: widget.categories
                .map<DropdownMenuItem<int>>((cat) {
                  return DropdownMenuItem<int>(
                    value: cat['id'],
                    child: Text(cat['name'] ?? ''),
                  );
                })
                .toList(),
            onChanged: (val) => setState(() => _selectedCategory = val),
          ),
          const SizedBox(height: 12),
          _buildPriceFields(),
          const SizedBox(height: 12),
          _buildStockUnitFields(),
        ]),
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: (_isUploading || _isLoading) ? null : _updateProduct,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save changes'),
        ),
      ),
      const SizedBox(height: 20),
    ]);
  }

  Widget _buildPriceFields() {
    return LayoutBuilder(builder: (context, constraints) {
      final pair = constraints.maxWidth >= 420;
      final cost = _buildTextField(
          'Cost price (₹)', _costPriceController,
          isNumber: true);
      final sell = _buildTextField('Selling price (₹) *',
          _sellingPriceController,
          isNumber: true);
      if (pair) {
        return Row(children: [
          Expanded(child: cost),
          const SizedBox(width: 12),
          Expanded(child: sell),
        ]);
      }
      return Column(children: [
        cost,
        const SizedBox(height: 12),
        sell,
      ]);
    });
  }

  Widget _buildStockUnitFields() {
    return LayoutBuilder(builder: (context, constraints) {
      final pair = constraints.maxWidth >= 420;
      final stock = _buildTextField('Stock quantity *', _stockController,
          isNumber: true);
      final unit = DropdownButtonFormField<String>(
        value: _selectedUnit,
        decoration: const InputDecoration(
          labelText: 'Unit *',
          prefixIcon: Icon(Icons.straighten_outlined),
        ),
        items: productUnits
            .map((unit) =>
                DropdownMenuItem(value: unit, child: Text(unit)))
            .toList(),
        onChanged: (unit) => setState(() => _selectedUnit = unit!),
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
        const SizedBox(height: 12),
        unit,
      ]);
    });
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
        isDense: true,
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