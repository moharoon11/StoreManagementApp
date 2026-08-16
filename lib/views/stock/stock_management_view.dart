import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class StockManagementView extends StatefulWidget {
  const StockManagementView({Key? key}) : super(key: key);

  @override
  State<StockManagementView> createState() => _StockManagementViewState();
}

class _StockManagementViewState extends State<StockManagementView> {
  bool _isLoading = true;
  List<dynamic> _movements = [];
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _fetchProducts();
    await _fetchMovements();
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await ApiService.get(ApiConfig.products,
          queryParameters: {'pageSize': '100'});
      if (res['success'] == true) {
        _products = res['data']['items'] ?? [];
      }
    } catch (_) {}
  }

  Future<void> _fetchMovements() async {
    try {
      final res = await ApiService.get(ApiConfig.stockMovements);
      if (res['success'] == true) {
        setState(() {
          _movements = res['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showAdjustStockDialog() {
    if (_products.isEmpty) return;

    int selectedProductId = _products.first['id'];
    final qtyController = TextEditingController();
    String reason = 'STOCK_ADDED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Adjust Product Stock',
                style: TextStyle(
                    color: Color(0xFF172033), fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedProductId,
                    style: const TextStyle(color: Color(0xFF172033)),
                    decoration:
                        const InputDecoration(labelText: 'Select Product'),
                    items: _products.map<DropdownMenuItem<int>>((p) {
                      return DropdownMenuItem<int>(
                        value: p['id'],
                        child:
                            Text('${p['name']} (Stock: ${p['stockQuantity']})'),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedProductId = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xFF172033)),
                    decoration: const InputDecoration(
                        labelText: 'Quantity Change (+ add, - reduce)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: reason,
                    style: const TextStyle(color: Color(0xFF172033)),
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: const [
                      DropdownMenuItem(
                          value: 'STOCK_ADDED', child: Text('STOCK_ADDED')),
                      DropdownMenuItem(
                          value: 'MANUAL_ADJUSTMENT',
                          child: Text('MANUAL_ADJUSTMENT')),
                      DropdownMenuItem(value: 'RETURN', child: Text('RETURN')),
                    ],
                    onChanged: (val) => setModalState(() => reason = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF6C7486)))),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyController.text) ?? 0;
                  if (qty == 0) return;

                  Navigator.pop(ctx);
                  await ApiService.post(ApiConfig.stockAdjust, {
                    'productId': selectedProductId,
                    'quantityChanged': qty,
                    'reason': reason,
                  });
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF365FF4),
                    foregroundColor: Colors.white),
                child: const Text('Submit Adjustment'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF365FF4)));
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Stock Movements',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172033),
                        letterSpacing: -0.5),
                    overflow: TextOverflow.ellipsis),
              ),
              ElevatedButton.icon(
                onPressed: _showAdjustStockDialog,
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Adjust Stock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF365FF4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _movements.isEmpty
                ? const Center(
                    child: Text('No stock movement records found.',
                        style: TextStyle(color: Color(0xFF6C7486))))
                : ListView.builder(
                    itemCount: _movements.length,
                    itemBuilder: (context, index) {
                      final m = _movements[index];
                      final isAddition = (m['quantityChanged'] as int) > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE6E8EF)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAddition
                                ? const Color(0xFFEAF9F6)
                                : const Color(0xFFFFF0F0),
                            child: Icon(
                              isAddition ? Icons.add : Icons.remove,
                              color: isAddition
                                  ? const Color(0xFF12A594)
                                  : const Color(0xFFE75C5C),
                              size: 20,
                            ),
                          ),
                          title: Text(m['productName'] ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF172033),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          subtitle: Text(
                              'Prev: ${m['previousQuantity']} → New: ${m['newQuantity']}  (${m['reason']})',
                              style: const TextStyle(
                                  color: Color(0xFF6C7486), fontSize: 12)),
                          trailing: Text(
                            '${isAddition ? '+' : ''}${m['quantityChanged']}',
                            style: TextStyle(
                              color: isAddition
                                  ? const Color(0xFF12A594)
                                  : const Color(0xFFE75C5C),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
