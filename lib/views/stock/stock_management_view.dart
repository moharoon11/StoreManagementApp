import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/feature_flags.dart';
import '../../services/api_service.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';
import 'upload_bill_view.dart';

class StockManagementView extends StatefulWidget {
  const StockManagementView({super.key});

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
      final res = await ApiService.get(
        ApiConfig.products,
        queryParameters: {'pageSize': '100'},
      );
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Adjust stock'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedProductId,
                  decoration:
                      const InputDecoration(labelText: 'Select product'),
                  items: _products.map<DropdownMenuItem<int>>((product) {
                    return DropdownMenuItem<int>(
                      value: product['id'],
                      child: Text(
                        '${product['name']} (${formatProductQuantity(product['stockQuantity'], product)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setModalState(() => selectedProductId = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
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
                      value: 'STOCK_ADDED',
                      child: Text('STOCK_ADDED'),
                    ),
                    DropdownMenuItem(
                      value: 'MANUAL_ADJUSTMENT',
                      child: Text('MANUAL_ADJUSTMENT'),
                    ),
                    DropdownMenuItem(
                      value: 'RETURN',
                      child: Text('RETURN'),
                    ),
                  ],
                  onChanged: (value) => setModalState(() => reason = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
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
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(
            eyebrow: 'Stock',
            title: 'Inventory movements',
            description:
                'Review movement history, import supplier bills, and adjust product quantities from a denser operations log.',
            action: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (FeatureFlags.enableUploadBill)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UploadBillView(),
                        ),
                      );
                      if (result == true) {
                        _loadData();
                      }
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('Upload bill'),
                  ),
                FilledButton.icon(
                  onPressed: _showAdjustStockDialog,
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Adjust stock'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdaptiveWrapGrid(
            minItemWidth: 190,
            children: [
              StatTile(
                label: 'Movement rows',
                value: '${_movements.length}',
                icon: Icons.swap_vert_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              StatTile(
                label: 'Tracked products',
                value: '${_products.length}',
                icon: Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SectionPanel(
              title: 'Movement log',
              subtitle: 'Recent quantity adjustments across the store.',
              child: _isLoading
                  ? const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _movements.isEmpty
                      ? const EmptyCanvas(
                          icon: Icons.inventory_2_outlined,
                          title: 'No stock movement records found',
                          detail:
                              'Inventory adjustments and bill imports will appear here.',
                        )
                      : ListView.separated(
                          itemCount: _movements.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final movement = Map<String, dynamic>.from(
                                _movements[index] as Map);
                            return _MovementCard(movement: movement);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});

  final Map<String, dynamic> movement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAddition = quantityValue(movement['quantityChanged']) > 0;
    final unit = (movement['unit'] ?? 'Piece').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final badge = StatusPill(
            label:
                '${isAddition ? '+' : ''}${formatQuantity(movement['quantityChanged'])} $unit',
            color: isAddition ? scheme.secondary : scheme.error,
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MovementIcon(isAddition: isAddition),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (movement['productName'] ?? '').toString(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Prev: ${formatQuantity(movement['previousQuantity'])} $unit → New: ${formatQuantity(movement['newQuantity'])} $unit',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  (movement['reason'] ?? '').toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                      ),
                ),
                const SizedBox(height: 10),
                badge,
              ],
            );
          }

          return Row(
            children: [
              _MovementIcon(isAddition: isAddition),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (movement['productName'] ?? '').toString(),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prev: ${formatQuantity(movement['previousQuantity'])} $unit → New: ${formatQuantity(movement['newQuantity'])} $unit',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (movement['reason'] ?? '').toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              badge,
            ],
          );
        },
      ),
    );
  }
}

class _MovementIcon extends StatelessWidget {
  const _MovementIcon({required this.isAddition});

  final bool isAddition;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: (isAddition ? scheme.secondary : scheme.error)
            .withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        isAddition ? Icons.add_rounded : Icons.remove_rounded,
        color: isAddition ? scheme.secondary : scheme.error,
      ),
    );
  }
}
