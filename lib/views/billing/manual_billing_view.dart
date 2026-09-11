import 'package:flutter/material.dart';

import '../../widgets/workspace_ui.dart';
import 'checkout_screen.dart';

class ManualBillingItemModel {
  final TextEditingController rateController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');

  double get rate => double.tryParse(rateController.text) ?? 0.0;
  int get quantity => int.tryParse(qtyController.text) ?? 0;
  double get total => rate * quantity;

  void dispose() {
    rateController.dispose();
    qtyController.dispose();
  }
}

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

  void _addItem() {
    setState(() => _items.add(ManualBillingItemModel()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double get _grandTotal {
    double total = 0;
    for (final item in _items) {
      total += item.total;
    }
    return total;
  }

  int get _validItemCount {
    var count = 0;
    for (final item in _items) {
      if (item.rate > 0 && item.quantity > 0) count++;
    }
    return count;
  }

  Future<void> _beginCheckout() async {
    if (_isOpeningCheckout) return;

    final validItems = <Map<String, dynamic>>[];
    for (final item in _items) {
      if (item.rate > 0 && item.quantity > 0) {
        validItems.add({
          'rate': item.rate,
          'quantity': item.quantity,
        });
      }
    }

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one item with a valid rate and quantity.',
          ),
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
    if (mounted) {
      setState(() => _isOpeningCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final narrowBar = MediaQuery.sizeOf(context).width < 680;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual bill'),
      ),
      body: WorkspacePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageIntro(
              eyebrow: 'Billing',
              title: 'Build a direct manual bill',
              description:
                  'Enter rate and quantity only. The checkout, payment, and invoice flow stays the same while the layout becomes denser and easier to scan.',
              action: FilledButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add line'),
              ),
            ),
            const SizedBox(height: 16),
            AdaptiveWrapGrid(
              minItemWidth: 180,
              children: [
                StatTile(
                  label: 'Line items',
                  value: '${_items.length}',
                  icon: Icons.format_list_bulleted_rounded,
                  color: scheme.primary,
                  note: 'Every card represents one bill line',
                ),
                StatTile(
                  label: 'Valid rows',
                  value: '$_validItemCount',
                  icon: Icons.check_circle_outline_rounded,
                  color: scheme.secondary,
                  note: 'Rows with both rate and quantity',
                ),
                StatTile(
                  label: 'Grand total',
                  value: '₹${_grandTotal.toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                  color: scheme.tertiary,
                  note: 'Calculated live while you type',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SectionPanel(
                title: 'Bill lines',
                subtitle:
                    'Use as many rows as you need. Empty lines are ignored during checkout.',
                action: OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add row'),
                ),
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _ManualBillLineCard(
                      index: index,
                      item: item,
                      canDelete: _items.length > 1,
                      onChanged: () => setState(() {}),
                      onDelete: () => _removeItem(index),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SurfacePanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: narrowBar
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ManualBillSummary(
                        total: _grandTotal,
                        validItemCount: _validItemCount,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isOpeningCheckout ? null : _beginCheckout,
                          icon: _isOpeningCheckout
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_outline_rounded, size: 18),
                          label: Text(
                            _isOpeningCheckout
                                ? 'Opening checkout...'
                                : 'Continue to checkout',
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _ManualBillSummary(
                          total: _grandTotal,
                          validItemCount: _validItemCount,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: FilledButton.icon(
                          onPressed: _isOpeningCheckout ? null : _beginCheckout,
                          icon: _isOpeningCheckout
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_outline_rounded, size: 18),
                          label: Text(
                            _isOpeningCheckout ? 'Opening...' : 'Checkout',
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ManualBillSummary extends StatelessWidget {
  const _ManualBillSummary({
    required this.total,
    required this.validItemCount,
  });

  final double total;
  final int validItemCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ready to bill',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${total.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          '$validItemCount valid line${validItemCount == 1 ? '' : 's'} included',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ManualBillLineCard extends StatelessWidget {
  const _ManualBillLineCard({
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: 'Line ${index + 1}',
                color: scheme.primary,
              ),
              const Spacer(),
              Text(
                '₹${item.total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.secondary,
                    ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Remove row',
                  icon: Icon(Icons.close_rounded, color: scheme.error, size: 18),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 520;
              if (narrow) {
                return Column(
                  children: [
                    _ManualField(
                      label: 'Rate (₹)',
                      controller: item.rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => onChanged(),
                    ),
                    const SizedBox(height: 10),
                    _ManualField(
                      label: 'Quantity',
                      controller: item.qtyController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => onChanged(),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _ManualField(
                      label: 'Rate (₹)',
                      controller: item.rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ManualField(
                      label: 'Quantity',
                      controller: item.qtyController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ManualField extends StatelessWidget {
  const _ManualField({
    required this.label,
    required this.controller,
    required this.keyboardType,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
}
