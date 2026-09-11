import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../config/feature_flags.dart';
import '../../services/adaptive_image_service.dart';
import '../../services/api_service.dart';
import '../../services/bill_upload_service.dart';
import '../../services/platform_capabilities.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';

class UploadBillView extends StatefulWidget {
  const UploadBillView({super.key});

  @override
  State<UploadBillView> createState() => _UploadBillViewState();
}

class _UploadBillViewState extends State<UploadBillView> {
  bool _isLoadingCategories = true;
  List<dynamic> _categories = [];

  bool _isExtracting = false;
  File? _pickedImageFile;
  List<ExtractedBillItem> _extractedItems = [];

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (!FeatureFlags.enableUploadBill) {
      return;
    }
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await ApiService.get(ApiConfig.categories);
      if (res['success'] == true && mounted) {
        setState(() {
          _categories = res['data'] ?? [];
          _isLoadingCategories = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image =
          await AdaptiveImageService.pickDirect(source, imageQuality: 80);
      if (image == null) return;

      setState(() {
        _pickedImageFile = File(image.path);
        _isExtracting = true;
        _extractedItems = [];
      });

      final items = await BillUploadService.extractBill(image.path);
      if (mounted) {
        setState(() {
          _extractedItems = items;
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _processBill() async {
    for (var i = 0; i < _extractedItems.length; i++) {
      final item = _extractedItems[i];
      if (item.productName.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item ${i + 1} is missing a name.')),
        );
        return;
      }
      if (item.sellingPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please set a selling price for ${item.productName}.',
            ),
          ),
        );
        return;
      }
      if (item.isNewProduct && item.categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a category for new product: ${item.productName}.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      await BillUploadService.processBill(_extractedItems);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory successfully updated!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _resetSelection() {
    setState(() {
      _pickedImageFile = null;
      _extractedItems = [];
      _isExtracting = false;
    });
  }

  int get _readyItems {
    var ready = 0;
    for (final item in _extractedItems) {
      final validCategory = !item.isNewProduct || item.categoryId != null;
      if (item.productName.trim().isNotEmpty &&
          item.sellingPrice > 0 &&
          validCategory) {
        ready++;
      }
    }
    return ready;
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.enableUploadBill) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Upload bill'),
        ),
        body: const WorkspacePage(
          child: EmptyCanvas(
            icon: Icons.toggle_off_rounded,
            title: 'Upload bill is disabled',
            detail:
                'Set ENABLE_UPLOAD_BILL=true when starting the app to turn this feature back on.',
          ),
        ),
      );
    }

    final reviewing = _pickedImageFile != null && !_isExtracting;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload bill'),
        actions: [
          if (reviewing)
            TextButton(
              onPressed: _resetSelection,
              child: const Text('Retake'),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoadingCategories)
            const Center(child: CircularProgressIndicator())
          else
            WorkspacePage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageIntro(
                    eyebrow: 'Stock',
                    title: 'Import a supplier bill',
                    description:
                        'Upload a wholesale bill, review the extracted products, and push the inventory update through a more compact approval flow.',
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _pickedImageFile == null && !_isExtracting
                        ? _UploadBillEmptyState(
                            onCamera: () => _pickImage(ImageSource.camera),
                            onGallery: () => _pickImage(ImageSource.gallery),
                            supportsCamera:
                                PlatformCapabilities.supportsCameraCapture,
                          )
                        : _isExtracting
                            ? _UploadBillExtractingState(
                                imageFile: _pickedImageFile,
                              )
                            : Column(
                                children: [
                                  AdaptiveWrapGrid(
                                    minItemWidth: 190,
                                    children: [
                                      StatTile(
                                        label: 'Extracted items',
                                        value: '${_extractedItems.length}',
                                        icon: Icons.receipt_long_outlined,
                                        color: scheme.primary,
                                      ),
                                      StatTile(
                                        label: 'Ready to import',
                                        value: '$_readyItems',
                                        icon:
                                            Icons.check_circle_outline_rounded,
                                        color: scheme.secondary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _BillPreviewPanel(
                                    imageFile: _pickedImageFile!,
                                    totalItems: _extractedItems.length,
                                    onRetake: _resetSelection,
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: SectionPanel(
                                      title: 'Extracted items',
                                      subtitle:
                                          'Review names, prices, quantities, and categories before updating stock.',
                                      child: ListView.separated(
                                        itemCount: _extractedItems.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 12),
                                        itemBuilder: (context, index) {
                                          final item = _extractedItems[index];
                                          return _ExtractedBillItemCard(
                                            item: item,
                                            categories: _categories,
                                            index: index,
                                            onChanged: () => setState(() {}),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
            ),
          if (_isProcessing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .18),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: reviewing
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SurfacePanel(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 560;
                      final summary = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Inventory update',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: scheme.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_readyItems of ${_extractedItems.length} items ready',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      );

                      final action = SizedBox(
                        width: narrow ? double.infinity : 250,
                        child: FilledButton.icon(
                          onPressed:
                              _extractedItems.isEmpty ? null : _processBill,
                          icon: const Icon(Icons.inventory_rounded, size: 18),
                          label: const Text('Confirm & update'),
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
            )
          : null,
    );
  }
}

class _UploadBillEmptyState extends StatelessWidget {
  const _UploadBillEmptyState({
    required this.onCamera,
    required this.onGallery,
    required this.supportsCamera,
  });

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final bool supportsCamera;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SurfacePanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 38,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Upload a wholesale bill',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The extractor will read product names, quantities, and prices from the bill image so you can confirm everything before it updates stock.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onGallery,
                    icon: Icon(
                      supportsCamera
                          ? Icons.photo_library_outlined
                          : Icons.upload_file_outlined,
                      size: 18,
                    ),
                    label: Text(
                      supportsCamera ? 'Choose image' : 'Browse bill image',
                    ),
                  ),
                  if (supportsCamera)
                    OutlinedButton.icon(
                      onPressed: onCamera,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Use camera'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadBillExtractingState extends StatelessWidget {
  const _UploadBillExtractingState({
    required this.imageFile,
  });

  final File? imageFile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SurfacePanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    imageFile!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Analyzing bill',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'This can take a few seconds while the products and prices are extracted.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillPreviewPanel extends StatelessWidget {
  const _BillPreviewPanel({
    required this.imageFile,
    required this.totalItems,
    required this.onRetake,
  });

  final File imageFile;
  final int totalItems;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final preview = ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              imageFile,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          );
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$totalItems items extracted',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Review each line before updating inventory.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: .62),
                    ),
              ),
            ],
          );
          final action = OutlinedButton(
            onPressed: onRetake,
            child: const Text('Retake'),
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    preview,
                    const SizedBox(width: 14),
                    Expanded(child: text),
                  ],
                ),
                const SizedBox(height: 12),
                action,
              ],
            );
          }

          return Row(
            children: [
              preview,
              const SizedBox(width: 14),
              Expanded(child: text),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _ExtractedBillItemCard extends StatelessWidget {
  const _ExtractedBillItemCard({
    required this.item,
    required this.categories,
    required this.index,
    required this.onChanged,
  });

  final ExtractedBillItem item;
  final List<dynamic> categories;
  final int index;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canUseCategory =
        categories.any((category) => category['id'] == item.categoryId);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.isNewProduct
            ? scheme.primary.withValues(alpha: .07)
            : scheme.secondary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isNewProduct ? scheme.primary : scheme.secondary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: 'Item ${index + 1}',
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: item.isNewProduct ? 'New product' : 'Matched',
                color: item.isNewProduct ? scheme.primary : scheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: item.productName,
            decoration: const InputDecoration(
              labelText: 'Product name',
            ),
            onChanged: (value) {
              item.productName = value;
              onChanged();
            },
          ),
          if (item.isNewProduct) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: canUseCategory ? item.categoryId : null,
              decoration: const InputDecoration(
                labelText: 'Category',
              ),
              items: categories.map<DropdownMenuItem<int>>((category) {
                return DropdownMenuItem<int>(
                  value: category['id'] as int,
                  child: Text((category['name'] ?? 'Untitled').toString()),
                );
              }).toList(),
              onChanged: (value) {
                item.categoryId = value;
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: productUnits.contains(item.unit)
                  ? item.unit
                  : productUnits.first,
              decoration: const InputDecoration(
                labelText: 'Unit',
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
                item.unit = value;
                onChanged();
              },
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              final fields = [
                _InlineBillField(
                  label: 'Quantity',
                  initialValue: item.quantity.toString(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    item.quantity = double.tryParse(value) ?? 0.0;
                    onChanged();
                  },
                ),
                _InlineBillField(
                  label: 'Cost (₹)',
                  initialValue: item.costPrice.toString(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    item.costPrice = double.tryParse(value) ?? 0.0;
                    onChanged();
                  },
                ),
                _InlineBillField(
                  label: 'Selling (₹)',
                  initialValue: item.sellingPrice.toString(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    item.sellingPrice = double.tryParse(value) ?? 0.0;
                    onChanged();
                  },
                ),
              ];

              if (narrow) {
                return Column(
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      fields[i],
                      if (i != fields.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 12),
                  Expanded(child: fields[1]),
                  const SizedBox(width: 12),
                  Expanded(child: fields[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InlineBillField extends StatelessWidget {
  const _InlineBillField({
    required this.label,
    required this.initialValue,
    required this.keyboardType,
    required this.onChanged,
  });

  final String label;
  final String initialValue;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}
