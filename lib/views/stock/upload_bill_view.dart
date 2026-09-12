import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../services/bill_upload_service.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/ui_breakpoints.dart';
import '../../widgets/workspace_ui.dart';

class UploadBillView extends StatefulWidget {
  const UploadBillView({Key? key}) : super(key: key);

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
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    }
  }

  Future<void> _processBill() async {
    for (var i = 0; i < _extractedItems.length; i++) {
      final item = _extractedItems[i];
      if (item.productName.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Item ${i + 1} is missing a name.')));
        return;
      }
      if (item.sellingPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Please set a Selling Price for ${item.productName}.')));
        return;
      }
      if (item.isNewProduct && item.categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Please select a Category for new product: ${item.productName}.')));
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      await BillUploadService.processBill(_extractedItems);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventory successfully updated!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Upload bill',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (_pickedImageFile == null && !_isExtracting)
                  _buildEmptyState()
                else if (_isExtracting)
                  _buildExtractingState()
                else
                  _buildReviewState(),
                if (_isProcessing)
                  Container(
                    color: scheme.scrim.withValues(alpha: .35),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: Ui.pagePadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 42, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text('Upload a purchase bill',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Text(
                'The assistant reads your bill and lists the products, quantities and cost prices for review.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .6),
                    fontSize: 12.5,
                    height: 1.4),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionTile(
                  icon: Icons.photo_camera_outlined,
                  label: 'Camera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 16),
                _buildActionTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 132,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: scheme.primary, size: 30),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildExtractingState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SpinKitDoubleBounce(color: Color(0xFF134E3A), size: 66),
          const SizedBox(height: 24),
          Text('Reading the bill...',
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('This usually takes a few seconds',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .55),
                  fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildReviewState() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SurfacePanel(
          accent: false,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _pickedImageFile != null
                  ? Image.file(_pickedImageFile!,
                      fit: BoxFit.cover, width: 52, height: 52)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_extractedItems.length} items extracted',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Review names and set selling prices',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: .55),
                          fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _pickedImageFile = null;
                  _extractedItems = [];
                });
              },
              child: const Text('Retake'),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: _extractedItems.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildItemCard(_extractedItems[index]),
              );
            },
          ),
        ),
        SurfacePanel(
          accent: false,
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _extractedItems.isEmpty ? null : _processBill,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Confirm & update inventory'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(ExtractedBillItem item) {
    final scheme = Theme.of(context).colorScheme;
    final tagColor = item.isNewProduct ? scheme.secondary : scheme.primary;

    return SurfacePanel(
      accent: false,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: item.productName,
                style: const TextStyle(fontSize: 13.5),
                decoration: const InputDecoration(
                  labelText: 'Product name',
                  isDense: true,
                ),
                onChanged: (val) => item.productName = val,
              ),
            ),
            const SizedBox(width: 10),
            LedgerTag(
              label: item.isNewProduct ? 'New product' : 'Match found',
              color: tagColor,
              icon: item.isNewProduct
                  ? Icons.add_circle_outline
                  : Icons.check_circle_outline,
            ),
          ]),
          if (item.isNewProduct) ...[
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, constraints) {
              final pair = constraints.maxWidth >= 420;
              final cat = DropdownButtonFormField<int>(
                value: item.categoryId,
                hint: const Text('Select category'),
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: _categories.map<DropdownMenuItem<int>>((cat) {
                  return DropdownMenuItem<int>(
                    value: cat['id'],
                    child: Text(cat['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (val) => setState(() => item.categoryId = val),
              );
              final unit = DropdownButtonFormField<String>(
                value: productUnits.contains(item.unit) ? item.unit : 'Piece',
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
                items: productUnits
                    .map((unit) =>
                        DropdownMenuItem(value: unit, child: Text(unit)))
                    .toList(),
                onChanged: (unit) => setState(() => item.unit = unit!),
              );
              if (pair) {
                return Row(children: [
                  Expanded(flex: 3, child: cat),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: unit),
                ]);
              }
              return Column(children: [
                cat,
                const SizedBox(height: 10),
                unit,
              ]);
            }),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            const gap = SizedBox(width: 8);
            final qty = _numberField(
                'Qty', item.quantity.toString(),
                (v) => item.quantity = double.tryParse(v) ?? 0,
                flex: 1);
            final cost = _numberField(
                'Cost (₹)', item.costPrice.toString(),
                (v) => item.costPrice = double.tryParse(v) ?? 0.0,
                flex: 2);
            final sell = _numberField(
                'Selling (₹)*', item.sellingPrice.toString(),
                (v) => item.sellingPrice = double.tryParse(v) ?? 0.0,
                flex: 2);
            if (constraints.maxWidth >= 360) {
              return Row(children: [qty, gap, cost, gap, sell]);
            }
            return Row(children: [qty, gap, cost]);
          }),
        ],
      ),
    );
  }

  Widget _numberField(
      String label, String initialValue, ValueChanged<String> onChanged,
      {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor:
              Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
        ),
        onChanged: onChanged,
      ),
    );
  }
}