import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/ui_breakpoints.dart';

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
          final scheme = Theme.of(context).colorScheme;
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Adjust Product Stock',
                style: TextStyle(
                    color: scheme.onSurface, fontWeight: FontWeight.w800)),
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
                  child: Text('Cancel',
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: .6)))),
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

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: Ui.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Stock Movements',
                    style: TextStyle(
                        fontSize: Ui.headingSize(context),
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: -0.5),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showAdjustStockDialog,
                icon: const Icon(Icons.edit_note, size: 17),
                label: const Text('Adjust Stock'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _movements.isEmpty
                ? Center(
                    child: Text('No stock movement records found.',
                        style:
                            TextStyle(color: scheme.onSurface.withValues(alpha: .6))))
                : ListView.builder(
                    itemCount: _movements.length,
                    itemBuilder: (context, index) {
                      final m = _movements[index];
                      final isAddition = (m['quantityChanged'] as int) > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: isAddition
                                ? scheme.secondary.withValues(alpha: .12)
                                : scheme.error.withValues(alpha: .1),
                            child: Icon(
                              isAddition ? Icons.add : Icons.remove,
                              color: isAddition ? scheme.secondary : scheme.error,
                              size: 18,
                            ),
                          ),
                          title: Text(m['productName'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                          subtitle: Text(
                              'Prev: ${m['previousQuantity']} → New: ${m['newQuantity']}  (${m['reason']})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: scheme.onSurface.withValues(alpha: .55),
                                  fontSize: 11)),
                          trailing: Text(
                            '${isAddition ? '+' : ''}${m['quantityChanged']}',
                            style: TextStyle(
                              color: isAddition ? scheme.secondary : scheme.error,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
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
