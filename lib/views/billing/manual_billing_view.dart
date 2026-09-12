import 'package:flutter/material.dart';
import '../../widgets/workspace_ui.dart';
import 'checkout_screen.dart';

class ManualBillingItemModel {
  final TextEditingController rateController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');

  void dispose() {
    rateController.dispose();
    qtyController.dispose();
  }
}

class ManualBillingView extends StatefulWidget {
  const ManualBillingView({Key? key}) : super(key: key);

  @override
  State<ManualBillingView> createState() => _ManualBillingViewState();
}

class _ManualBillingViewState extends State<ManualBillingView> {
  final List<ManualBillingItemModel> _items = [ManualBillingItemModel()];
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  @override
  void dispose() {
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(ManualBillingItemModel());
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].dispose();
        _items.removeAt(index);
      });
    }
  }

  double get _grandTotal {
    double total = 0;
    for (var item in _items) {
      final rate = double.tryParse(item.rateController.text) ?? 0;
      final qty = int.tryParse(item.qtyController.text) ?? 0;
      total += (rate * qty);
    }
    return total;
  }

  void _beginCheckout() {
    if (!_formKey.currentState!.validate()) return;

    bool hasValidItem = false;
    for (var item in _items) {
      final rate = double.tryParse(item.rateController.text) ?? 0;
      final qty = int.tryParse(item.qtyController.text) ?? 0;
      if (rate > 0 && qty > 0) {
        hasValidItem = true;
        break;
      }
    }

    if (!hasValidItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please enter at least one valid item with rate and quantity.')),
      );
      return;
    }

    final validItems = <Map<String, dynamic>>[];
    for (var item in _items) {
      final rate = double.tryParse(item.rateController.text) ?? 0;
      final qty = int.tryParse(item.qtyController.text) ?? 0;
      if (rate > 0 && qty > 0) {
        validItems.add({
          'rate': rate,
          'quantity': qty,
        });
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          isManual: true,
          manualItems: validItems,
          manualTotal: _grandTotal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Manual bill',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SurfacePanel(
                        accent: false,
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          LedgerStamp(
                              icon: Icons.edit_note_rounded,
                              color: scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bill lines',
                                    style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(
                                    'Enter a rate and quantity for each item on the bill.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: scheme.onSurface
                                            .withValues(alpha: .55),
                                        fontSize: 11.5)),
                              ],
                            ),
                          ),
                          LedgerTag(
                              label: '${_items.length}',
                              color: scheme.primary),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < _items.length; i++) ...[
                        _buildLineCard(i),
                        const SizedBox(height: 10),
                      ],
                      OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add another line'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SurfacePanel(
              accent: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Grand total',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface.withValues(alpha: .6))),
                    Text('₹${_grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: scheme.onSurface)),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : _beginCheckout,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Checkout'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineCard(int index) {
    final scheme = Theme.of(context).colorScheme;
    final item = _items[index];
    final rate = double.tryParse(item.rateController.text) ?? 0;
    final qty = int.tryParse(item.qtyController.text) ?? 0;
    final itemTotal = rate * qty;

    return SurfacePanel(
      accent: false,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('LINE ${index + 1}',
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .5),
                    fontSize: 10.5,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            if (_items.length > 1)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 30, minHeight: 30),
                icon: Icon(Icons.close_rounded,
                    size: 17, color: scheme.error.withValues(alpha: .7)),
                onPressed: () => _removeItem(index),
              ),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: item.rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  labelText: 'Rate (₹)',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: item.qtyController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 86,
              child: Text(
                '₹${itemTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: scheme.primary),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}