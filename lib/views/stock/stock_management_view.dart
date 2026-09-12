import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';
import 'upload_bill_view.dart';

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
    await Future.wait([_fetchProducts(), _fetchMovements()]);
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
      if (res['success'] == true && mounted) {
        setState(() {
          _movements = res['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAdjustStockDialog() {
    if (_products.isEmpty) return;

    int selectedProductId = _products.first['id'] as int;
    final qtyController = TextEditingController();
    String reason = 'STOCK_ADDED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Adjust product stock'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedProductId,
                    decoration:
                        const InputDecoration(labelText: 'Select product'),
                    items: _products.map<DropdownMenuItem<int>>((p) {
                      return DropdownMenuItem<int>(
                        value: p['id'],
                        child: Text(
                            '${p['name']} (${formatProductQuantity(p['stockQuantity'], p)})'),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedProductId = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantity change (+ add, - reduce)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: const [
                      DropdownMenuItem(
                          value: 'STOCK_ADDED', child: Text('STOCK_ADDED')),
                      DropdownMenuItem(
                          value: 'MANUAL_ADJUSTMENT',
                          child: Text('MANUAL_ADJUSTMENT')),
                      DropdownMenuItem(
                          value: 'RETURN', child: Text('RETURN')),
                    ],
                    onChanged: (val) => setModalState(() => reason = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Submit adjustment'),
                onPressed: () async {
                  final qty = double.tryParse(qtyController.text) ?? 0;
                  if (qty == 0) return;
                  Navigator.pop(ctx);
                  await ApiService.post(ApiConfig.stockAdjust, {
                    'productId': selectedProductId,
                    'quantityChanged': qty,
                    'reason': reason,
                  });
                  _loadData();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return WorkspacePage(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageIntro(
          eyebrow: 'Inventory ledger',
          title: 'Stock movements',
          description:
              'Every addition, return and manual adjustment recorded against your catalogue.',
          action: Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UploadBillView()),
                );
                if (result == true) _loadData();
              },
              icon: const Icon(Icons.receipt_long_outlined, size: 17),
              label: const Text('Upload bill'),
            ),
            FilledButton.icon(
              onPressed: _showAdjustStockDialog,
              icon: const Icon(Icons.edit_note_rounded, size: 17),
              label: const Text('Adjust stock'),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_movements.isEmpty)
          const Expanded(
            child: EmptyCanvas(
              icon: Icons.sync_alt,
              title: 'No movements yet',
              detail: 'Stock movements appear here once you upload a bill '
                  'or adjust stock quantities.',
            ),
          )
        else
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 640;
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: _movements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _movementRow(_movements[index], wide, scheme),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _movementRow(dynamic m, bool wide, ColorScheme scheme) {
    final isAddition = quantityValue(m['quantityChanged']) > 0;
    final unit = (m['unit'] ?? 'Piece').toString();
    final color = isAddition ? scheme.primary : scheme.error;
    final reason = (m['reason'] ?? '').toString();

    return SurfacePanel(
      accent: false,
      padding: EdgeInsets.all(wide ? 14 : 12),
      child: Row(children: [
        LedgerStamp(
          icon: isAddition ? Icons.add_rounded : Icons.remove_rounded,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['productName'] ?? 'Product'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
            const SizedBox(height: 3),
            Text(
                '${formatQuantity(m['previousQuantity'])} to ${formatQuantity(m['newQuantity'])} $unit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .55),
                    fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              LedgerTag(
                label: isAddition ? 'Added' : 'Removed',
                color: color,
                icon: isAddition ? Icons.add : Icons.remove,
              ),
              if (reason.isNotEmpty)
                LedgerTag(
                  label: reason.replaceAll('_', ' '),
                  color: scheme.onSurface.withValues(alpha: .5),
                ),
            ]),
          ]),
        ),
        if (wide) const SizedBox(width: 10),
        Text(
          '${isAddition ? '+' : '-'}${formatQuantity(m['quantityChanged'])} $unit',
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ]),
    );
  }
}