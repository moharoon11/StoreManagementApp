import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';

class ProductEditView extends StatefulWidget {
  const ProductEditView({
    super.key,
    required this.product,
    required this.categories,
  });

  final Map<String, dynamic> product;
  final List<dynamic> categories;

  @override
  State<ProductEditView> createState() => _ProductEditViewState();
}

class _ProductEditViewState extends State<ProductEditView> {
  late final TextEditingController _nameController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _stockController;

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
      text: widget.product['costPrice']?.toString() ?? '',
    );
    _sellingPriceController = TextEditingController(
      text: widget.product['sellingPrice']?.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: widget.product['stockQuantity']?.toString() ?? '',
    );
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
      final image = await picker.pickImage(source: source, imageQuality: 80);
      if (image == null) return;

      setState(() {
        _pickedImageFile = File(image.path);
        _isUploading = true;
      });

      final url = await ApiService.uploadImage(image.path);
      if (url != null && mounted) {
        setState(() {
          _productImageUrl = url;
          _isUploading = false;
        });
      } else if (mounted) {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _updateProduct() async {
    if (_nameController.text.trim().isEmpty ||
        _sellingPriceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and selling price are required.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final body = {
      'name': _nameController.text.trim(),
      'costPrice': double.tryParse(_costPriceController.text) ?? 0.0,
      'sellingPrice': double.tryParse(_sellingPriceController.text) ?? 0.0,
      'stockQuantity': double.tryParse(_stockController.text) ?? 0.0,
      'unit': _selectedUnit,
      'imageUrl': _productImageUrl,
      if (_selectedCategory != null) 'categoryId': _selectedCategory!,
    };

    try {
      final res = await ApiService.put(
        '${ApiConfig.products}/${widget.product['id']}',
        body,
      );
      if (res['success'] == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to update product.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product'),
        content: const Text(
          'Are you sure you want to delete this product? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res =
          await ApiService.delete('${ApiConfig.products}/${widget.product['id']}');
      if (res['success'] == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to delete product.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSelectedCategory = widget.categories.any(
      (category) => category['id'] == _selectedCategory,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit product'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _deleteProduct,
            tooltip: 'Delete product',
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          ),
        ],
      ),
      body: Stack(
        children: [
          WorkspacePage(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PageIntro(
                        eyebrow: 'Products',
                        title: 'Refine this catalogue item',
                        description:
                            'Update category, pricing, stock, unit, and imagery while keeping the product workflow unchanged.',
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 820;
                          final imagePanel = _ImageEditorPanel(
                            imageUrl: _productImageUrl,
                            pickedImageFile: _pickedImageFile,
                            isUploading: _isUploading,
                            onTap: _showImageOptions,
                          );
                          final detailsPanel = SectionPanel(
                            title: 'Item details',
                            subtitle:
                                'Keep the values tight and current so the catalogue stays clean.',
                            child: Column(
                              children: [
                                TextField(
                                  controller: _nameController,
                                  onChanged: (_) => setState(() {}),
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Product name *',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  value: hasSelectedCategory ? _selectedCategory : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                  ),
                                  items: widget.categories
                                      .map<DropdownMenuItem<int>>((category) {
                                    return DropdownMenuItem<int>(
                                      value: category['id'] as int,
                                      child: Text(
                                        (category['name'] ?? 'Untitled')
                                            .toString(),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedCategory = value);
                                  },
                                ),
                                const SizedBox(height: 12),
                                _ResponsiveFieldPair(
                                  first: TextField(
                                    controller: _costPriceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Cost price (₹)',
                                    ),
                                  ),
                                  second: TextField(
                                    controller: _sellingPriceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Selling price (₹) *',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _ResponsiveFieldPair(
                                  first: TextField(
                                    controller: _stockController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Stock quantity *',
                                    ),
                                  ),
                                  second: DropdownButtonFormField<String>(
                                    value: productUnits.contains(_selectedUnit)
                                        ? _selectedUnit
                                        : productUnits.first,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit *',
                                    ),
                                    items: productUnits
                                        .map(
                                          (unit) => DropdownMenuItem<String>(
                                            value: unit,
                                            child: Text(unit),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedUnit = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 304, child: imagePanel),
                                const SizedBox(width: 16),
                                Expanded(child: detailsPanel),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              imagePanel,
                              const SizedBox(height: 16),
                              detailsPanel,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading || _isUploading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .16),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SurfacePanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 520;
                final summary = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Editing product',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _nameController.text.trim().isEmpty
                          ? 'Catalogue item'
                          : _nameController.text.trim(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                );

                final action = SizedBox(
                  width: narrow ? double.infinity : 220,
                  child: FilledButton.icon(
                    onPressed: (_isLoading || _isUploading) ? null : _updateProduct,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _isUploading ? 'Uploading image...' : 'Save changes',
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
  }
}

class _ImageEditorPanel extends StatelessWidget {
  const _ImageEditorPanel({
    required this.imageUrl,
    required this.pickedImageFile,
    required this.isUploading,
    required this.onTap,
  });

  final String imageUrl;
  final File? pickedImageFile;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Product image',
      subtitle: 'Tap the frame to replace the current artwork.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            height: 292,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: .22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: isUploading
                ? const Center(child: CircularProgressIndicator())
                : pickedImageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(
                          pickedImageFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) =>
                                  const _ProductImagePlaceholder(),
                            ),
                          )
                        : const _ProductImagePlaceholder(),
          ),
        ),
      ),
    );
  }
}

class _ResponsiveFieldPair extends StatelessWidget {
  const _ResponsiveFieldPair({
    required this.first,
    required this.second,
  });

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
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
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color: scheme.primary,
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            'Upload product image',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: .62),
                ),
          ),
        ],
      ),
    );
  }
}
