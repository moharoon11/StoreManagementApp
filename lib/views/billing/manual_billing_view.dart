import 'package:flutter/material.dart';

import 'checkout_screen.dart';

class ManualBillingItemModel {
  final TextEditingController rateController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');

  double get rate => double.tryParse(rateController.text) ?? 0;
  int get quantity => int.tryParse(qtyController.text) ?? 0;
  double get total => rate * quantity;

  void dispose() {
    rateController.dispose();
    qtyController.dispose();
  }
}

/// Direct-entry billing, deliberately kept close to a familiar invoice grid.
/// Payment and checkout remain on the existing flow.
class ManualBillingView extends StatefulWidget {
  const ManualBillingView({super.key});

  @override
  State<ManualBillingView> createState() => _ManualBillingViewState();
}

class _ManualBillingViewState extends State<ManualBillingView> {
  final List<ManualBillingItemModel> _items = [ManualBillingItemModel()];
  bool _isOpeningCheckout = false;

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(ManualBillingItemModel()));

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double get _grandTotal => _items.fold(0, (total, item) => total + item.total);

  Future<void> _beginCheckout() async {
    if (_isOpeningCheckout) return;
    final validItems = [
      for (final item in _items)
        if (item.rate > 0 && item.quantity > 0)
          {'rate': item.rate, 'quantity': item.quantity},
    ];

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Add at least one item with a valid rate and quantity.'),
        ),
      );
      return;
    }

    setState(() => _isOpeningCheckout = true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          isManual: true,
          manualItems: validItems,
          manualTotal: _grandTotal,
        ),
      ),
    );
    if (mounted) setState(() => _isOpeningCheckout = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Normal bill'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text('#')),
                SizedBox(width: 12),
                Expanded(flex: 4, child: Text('Rate (₹)')),
                SizedBox(width: 12),
                Expanded(flex: 3, child: Text('Qty')),
                SizedBox(width: 12),
                Expanded(flex: 3, child: Text('Total')),
              ],
            ),
          ),
          Divider(color: scheme.outlineVariant, height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < _items.length; index++) ...[
                  _ManualBillLine(
                    index: index,
                    item: _items[index],
                    canDelete: _items.length > 1,
                    onChanged: () => setState(() {}),
                    onDelete: () => _removeItem(index),
                  ),
                  Divider(color: scheme.outlineVariant, height: 1),
                ],
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add item'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Grand total',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      '₹${_grandTotal.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 168,
                child: FilledButton(
                  onPressed: _isOpeningCheckout ? null : _beginCheckout,
                  child: _isOpeningCheckout
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Checkout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualBillLine extends StatelessWidget {
  const _ManualBillLine({
    required this.index,
    required this.item,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final ManualBillingItemModel item;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('${index + 1}.',
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: TextField(
              controller: item.rateController,
              onChanged: (_) => onChanged(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0.00'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: TextField(
              controller: item.qtyController,
              onChanged: (_) => onChanged(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              '₹${item.total.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: scheme.secondary),
            ),
          ),
          if (canDelete)
            SizedBox(
              width: 26,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 26, height: 26),
                onPressed: onDelete,
                icon: Icon(Icons.close_rounded, size: 17, color: scheme.error),
                tooltip: 'Remove item',
              ),
            ),
        ],
      ),
    );
  }
}
