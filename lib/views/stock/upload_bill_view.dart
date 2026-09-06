import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../services/bill_upload_service.dart';
import '../../utils/quantity_utils.dart';

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
      if (res['success'] == true) {
        setState(() {
          _categories = res['data'] ?? [];
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingCategories = false);
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

        setState(() {
          _extractedItems = items;
          _isExtracting = false;
        });
      }
    } catch (e) {
      setState(() => _isExtracting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    }
  }

  Future<void> _processBill() async {
    // Validation
    for (var i = 0; i < _extractedItems.length; i++) {
      final item = _extractedItems[i];
      if (item.productName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item ${i + 1} is missing a name.')));
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
        Navigator.pop(context, true); // Go back and indicate success
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Upload Bill',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
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
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long,
                size: 64, color: Color(0xFF365FF4)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Upload a Wholesale Bill',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F1728)),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Our AI will automatically extract products, quantities, and prices from your bill image.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6C7486)),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(width: 20),
              _buildActionButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD2D6E0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF365FF4), size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFF0F1728))),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SpinKitDoubleBounce(color: Color(0xFF365FF4), size: 80),
          const SizedBox(height: 24),
          const Text(
            'AI is analyzing the bill...',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F1728)),
          ),
          const SizedBox(height: 8),
          const Text(
            'This might take a few seconds',
            style: TextStyle(color: Color(0xFF6C7486)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: _pickedImageFile != null
                      ? DecorationImage(
                          image: FileImage(_pickedImageFile!),
                          fit: BoxFit.cover)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_extractedItems.length} Items Extracted',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('Please review and set selling prices',
                        style:
                            TextStyle(color: Color(0xFF6C7486), fontSize: 12)),
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
              )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _extractedItems.length,
            itemBuilder: (context, index) {
              return _buildItemCard(_extractedItems[index], index);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5))
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _extractedItems.isEmpty ? null : _processBill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF365FF4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm & Update Inventory',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildItemCard(ExtractedBillItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: item.isNewProduct
                ? const Color(0xFFE2E8F0)
                : const Color(0xFFC6F6D5),
            width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.productName,
                    decoration: const InputDecoration(
                        labelText: 'Product Name',
                        border: UnderlineInputBorder()),
                    onChanged: (val) => item.productName = val,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isNewProduct
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.isNewProduct ? 'New Product' : 'Match Found',
                    style: TextStyle(
                      color: item.isNewProduct
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF16A34A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),
            if (item.isNewProduct) ...[
              DropdownButtonFormField<int>(
                value: item.categoryId,
                hint: const Text('Select Category'),
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), isDense: true),
                items: _categories.map<DropdownMenuItem<int>>((cat) {
                  return DropdownMenuItem<int>(
                    value: cat['id'],
                    child: Text(cat['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (val) => setState(() => item.categoryId = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: productUnits.contains(item.unit) ? item.unit : 'Piece',
                decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: productUnits
                    .map((unit) =>
                        DropdownMenuItem(value: unit, child: Text(unit)))
                    .toList(),
                onChanged: (unit) => setState(() => item.unit = unit!),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                        isDense: true),
                    onChanged: (val) =>
                        item.quantity = double.tryParse(val) ?? 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item.costPrice.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Cost (₹)',
                        border: OutlineInputBorder(),
                        isDense: true),
                    onChanged: (val) =>
                        item.costPrice = double.tryParse(val) ?? 0.0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item.sellingPrice.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Selling (₹)*',
                        border: OutlineInputBorder(),
                        isDense: true),
                    onChanged: (val) =>
                        item.sellingPrice = double.tryParse(val) ?? 0.0,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
