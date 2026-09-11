import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/platform_capabilities.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    this.isManual = false,
    this.manualItems,
    this.manualTotal,
  });

  final bool isManual;
  final List<Map<String, dynamic>>? manualItems;
  final double? manualTotal;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  late final TextEditingController _amountReceivedController;

  DateTime _invoiceDate = DateTime.now();
  bool _isReceived = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final total = widget.isManual
        ? widget.manualTotal ?? 0.0
        : Provider.of<AppProvider>(context, listen: false).cartTotal;
    _amountReceivedController =
        TextEditingController(text: total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _amountReceivedController.dispose();
    super.dispose();
  }

  Future<void> _completeCheckout() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AppProvider>();
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      final customerName = _nameController.text.trim();
      final customerMobile = _mobileController.text.trim();
      final invoiceDate = DateFormat('yyyy-MM-dd').format(_invoiceDate);
      final grandTotal =
          widget.isManual ? widget.manualTotal ?? 0.0 : provider.cartTotal;
      final amountReceived = double.tryParse(_amountReceivedController.text) ??
          (_isReceived ? grandTotal : 0.0);

      late final Map<String, dynamic> response;
      if (widget.isManual) {
        response = await ApiService.post(ApiConfig.manualCheckout, {
          'customerName': customerName,
          'customerMobileNumber': customerMobile,
          'isReceived': _isReceived,
          'amountReceived': amountReceived,
          'invoiceDate': invoiceDate,
          'items': widget.manualItems,
        });
      } else {
        final items = provider.cartItems.values.map((item) {
          return {
            'productId': item['product']['id'],
            'quantity': item['quantity'],
          };
        }).toList();

        response = await ApiService.post(ApiConfig.checkout, {
          'customerName': customerName,
          'customerMobileNumber': customerMobile,
          'isReceived': _isReceived,
          'amountReceived': amountReceived,
          'invoiceDate': invoiceDate,
          'items': items,
        });
      }

      if (response['success'] == true) {
        final invoice = response['data'];
        if (!widget.isManual) {
          provider.clearCart();
        }
        if (!mounted) return;
        final navigator = Navigator.of(context);
        navigator.pop();
        await _showInvoiceSuccessDialog(
            navigator.context, invoice, _invoiceDate);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content:
                Text((response['message'] ?? 'Checkout failed.').toString()),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Checkout error: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _selectInvoiceDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select invoice date',
    );
    if (selected != null && mounted) {
      setState(() => _invoiceDate = selected);
    }
  }

  List<_PreviewLine> _previewLines(AppProvider provider) {
    if (widget.isManual) {
      final items = widget.manualItems ?? const <Map<String, dynamic>>[];
      return items.asMap().entries.map((entry) {
        final item = entry.value;
        final qty = quantityValue(item['quantity'] ?? item['qty']);
        final price = (item['rate'] as num?)?.toDouble() ??
            (item['price'] as num?)?.toDouble() ??
            0.0;
        return _PreviewLine(
          title: 'Manual item ${entry.key + 1}',
          quantity: qty,
          unit: '',
          price: price,
        );
      }).toList();
    }

    return provider.cartItems.values.map((item) {
      final product = Map<String, dynamic>.from(item['product'] as Map);
      return _PreviewLine(
        title: (product['name'] ?? 'Product').toString(),
        quantity: quantityValue(item['quantity']),
        unit: productUnit(product),
        price: (product['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  Future<void> _showInvoiceSuccessDialog(
    BuildContext context,
    dynamic invoice,
    DateTime invoiceDate,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final invoiceId = invoice['id'] as int;
    final pdfFilename = 'Invoice_${invoice['invoiceNumber']}.pdf';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: scheme.secondary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Checkout completed',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _InvoiceMetaRow(
                      label: 'Invoice number',
                      value: '${invoice['invoiceNumber']}',
                    ),
                    const SizedBox(height: 8),
                    _InvoiceMetaRow(
                      label: 'Invoice date',
                      value: DateFormat('dd MMM yyyy').format(invoiceDate),
                    ),
                    const SizedBox(height: 8),
                    _InvoiceMetaRow(
                      label: 'Grand total',
                      value: '₹${invoice['grandTotal']}',
                      accent: scheme.primary,
                    ),
                    const SizedBox(height: 8),
                    _InvoiceMetaRow(
                      label: 'Balance due',
                      value: '₹${invoice['balanceDue'] ?? '0.00'}',
                      accent:
                          ((invoice['balanceDue'] as num?)?.toDouble() ?? 0) > 0
                              ? scheme.error
                              : scheme.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InvoiceActionButton(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Save PDF',
                    color: scheme.error,
                    onTap: () async {
                      try {
                        final bytes = await InvoicePdfService.fetch(invoiceId);
                        final wasSaved =
                            await InvoicePdfService.save(bytes, pdfFilename);
                        if (dialogContext.mounted && wasSaved) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                PlatformCapabilities.isDesktop
                                    ? 'PDF saved locally.'
                                    : 'PDF saved successfully.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Error saving PDF: $e')),
                          );
                        }
                      }
                    },
                  ),
                  _InvoiceActionButton(
                    icon: PlatformCapabilities.opensPdfInsteadOfShare
                        ? Icons.open_in_new_rounded
                        : Icons.share_outlined,
                    label: PlatformCapabilities.opensPdfInsteadOfShare
                        ? 'Open PDF'
                        : 'Share',
                    color: scheme.secondary,
                    onTap: () async {
                      try {
                        final bytes = await InvoicePdfService.fetch(invoiceId);
                        await Printing.sharePdf(
                          bytes: bytes,
                          filename: pdfFilename,
                          subject: 'Invoice ${invoice['invoiceNumber']}',
                          body:
                              'Invoice #${invoice['invoiceNumber']} - Total: ₹${invoice['grandTotal']}',
                        );
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                PlatformCapabilities.opensPdfInsteadOfShare
                                    ? 'Error opening PDF: $e'
                                    : 'Error sharing PDF: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _InvoiceActionButton(
                    icon: Icons.print_outlined,
                    label: 'Print',
                    color: scheme.primary,
                    onTap: () async {
                      try {
                        final bytes = await InvoicePdfService.fetch(invoiceId);
                        await Printing.layoutPdf(
                          onLayout: (format) async => bytes,
                          name: pdfFilename,
                        );
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Error printing PDF: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final lines = _previewLines(provider);
    final grandTotal =
        widget.isManual ? widget.manualTotal ?? 0.0 : provider.cartTotal;
    final amountReceived = double.tryParse(_amountReceivedController.text) ??
        (_isReceived ? grandTotal : 0.0);
    final balanceDue =
        (grandTotal - amountReceived).clamp(0.0, double.infinity);
    final wide = MediaQuery.sizeOf(context).width >= 940;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isManual ? 'Manual checkout' : 'Checkout'),
      ),
      body: WorkspacePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageIntro(
              eyebrow: widget.isManual ? 'Manual bill' : 'Checkout',
              title: 'Review payment and complete the sale',
              description:
                  'Customer details, payment receipt, and invoice items are grouped into a calmer layout so the last step feels quick instead of cramped.',
            ),
            const SizedBox(height: 16),
            AdaptiveWrapGrid(
              minItemWidth: 180,
              children: [
                StatTile(
                  label: 'Bill lines',
                  value: '${lines.length}',
                  icon: Icons.receipt_long_outlined,
                  color: scheme.primary,
                  note: widget.isManual
                      ? 'Manual entries prepared for billing'
                      : 'Products in the current checkout',
                ),
                StatTile(
                  label: 'Grand total',
                  value: '₹${grandTotal.toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                  color: scheme.secondary,
                  note: 'Current bill amount',
                ),
                StatTile(
                  label: 'Balance due',
                  value: '₹${balanceDue.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: balanceDue > 0 ? scheme.error : scheme.tertiary,
                  note: balanceDue > 0
                      ? 'Outstanding after this checkout'
                      : 'Marked as fully received',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: lines.isEmpty
                  ? const EmptyCanvas(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Nothing to check out',
                      detail:
                          'Add products or manual bill lines before opening checkout.',
                    )
                  : Form(
                      key: _formKey,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final details = _CheckoutDetailsPanel(
                            nameController: _nameController,
                            mobileController: _mobileController,
                            amountReceivedController: _amountReceivedController,
                            invoiceDate: _invoiceDate,
                            isReceived: _isReceived,
                            grandTotal: grandTotal,
                            balanceDue: balanceDue,
                            onSelectInvoiceDate: _selectInvoiceDate,
                            onToggleReceived: (value) {
                              setState(() {
                                _isReceived = value;
                                if (_isReceived) {
                                  _amountReceivedController.text =
                                      grandTotal.toStringAsFixed(2);
                                } else {
                                  _amountReceivedController.text = '0.00';
                                }
                              });
                            },
                            onAmountChanged: () => setState(() {}),
                          );

                          final review = _CheckoutReviewPanel(
                            lines: lines,
                            grandTotal: grandTotal,
                          );

                          if (wide && constraints.maxWidth >= 880) {
                            return ListView(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: details),
                                    const SizedBox(width: 16),
                                    Expanded(child: review),
                                  ],
                                ),
                              ],
                            );
                          }

                          return ListView(
                            children: [
                              details,
                              const SizedBox(height: 16),
                              review,
                            ],
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                final summary = _CheckoutBottomSummary(
                  grandTotal: grandTotal,
                  balanceDue: balanceDue,
                );

                final action = SizedBox(
                  width: narrow ? double.infinity : 230,
                  child: FilledButton.icon(
                    onPressed: _isProcessing || lines.isEmpty
                        ? null
                        : _completeCheckout,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded,
                            size: 18),
                    label: Text(
                      _isProcessing ? 'Processing...' : 'Complete checkout',
                    ),
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
      ),
    );
  }
}

class _PreviewLine {
  const _PreviewLine({
    required this.title,
    required this.quantity,
    required this.unit,
    required this.price,
  });

  final String title;
  final double quantity;
  final String unit;
  final double price;

  double get total => quantity * price;
}

class _CheckoutDetailsPanel extends StatelessWidget {
  const _CheckoutDetailsPanel({
    required this.nameController,
    required this.mobileController,
    required this.amountReceivedController,
    required this.invoiceDate,
    required this.isReceived,
    required this.grandTotal,
    required this.balanceDue,
    required this.onSelectInvoiceDate,
    required this.onToggleReceived,
    required this.onAmountChanged,
  });

  final TextEditingController nameController;
  final TextEditingController mobileController;
  final TextEditingController amountReceivedController;
  final DateTime invoiceDate;
  final bool isReceived;
  final double grandTotal;
  final double balanceDue;
  final VoidCallback onSelectInvoiceDate;
  final ValueChanged<bool> onToggleReceived;
  final VoidCallback onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        SectionPanel(
          title: 'Customer details',
          subtitle: 'Customer info and invoice date for the sale.',
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Customer name (optional)',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Customer mobile number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  final mobile = (value ?? '').trim();
                  if (mobile.isEmpty) {
                    return 'Customer mobile number is required.';
                  }
                  if (!RegExp(r'^[0-9+\-\s()]{7,20}$').hasMatch(mobile)) {
                    return 'Enter a valid mobile number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: onSelectInvoiceDate,
                borderRadius: BorderRadius.circular(20),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Invoice date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    suffixIcon: Icon(Icons.edit_calendar_outlined),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(invoiceDate),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionPanel(
          title: 'Payment receipt',
          subtitle: 'Capture how much was received right now.',
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Received in full',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isReceived
                                ? 'This bill is marked as paid.'
                                : 'You can keep an outstanding balance.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: isReceived,
                      onChanged: onToggleReceived,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountReceivedController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => onAmountChanged(),
                decoration: const InputDecoration(
                  labelText: 'Amount received',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniSummaryCard(
                      label: 'Total',
                      value: '₹${grandTotal.toStringAsFixed(2)}',
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniSummaryCard(
                      label: 'Balance due',
                      value: '₹${balanceDue.toStringAsFixed(2)}',
                      color: balanceDue > 0 ? scheme.error : scheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckoutReviewPanel extends StatelessWidget {
  const _CheckoutReviewPanel({
    required this.lines,
    required this.grandTotal,
  });

  final List<_PreviewLine> lines;
  final double grandTotal;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Bill review',
      subtitle:
          '${lines.length} line${lines.length == 1 ? '' : 's'} in this sale.',
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            _CheckoutItemTile(index: i + 1, line: lines[i]),
            if (i != lines.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          Divider(
              height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Grand total',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                '₹${grandTotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutItemTile extends StatelessWidget {
  const _CheckoutItemTile({
    required this.index,
    required this.line,
  });

  final int index;
  final _PreviewLine line;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = line.unit.isEmpty ? '' : ' ${line.unit}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatQuantity(line.quantity)}$unit x ₹${line.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${line.total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.secondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _CheckoutBottomSummary extends StatelessWidget {
  const _CheckoutBottomSummary({
    required this.grandTotal,
    required this.balanceDue,
  });

  final double grandTotal;
  final double balanceDue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sale summary',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${grandTotal.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          balanceDue > 0
              ? '₹${balanceDue.toStringAsFixed(2)} still due'
              : 'Fully received',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: balanceDue > 0 ? scheme.error : scheme.secondary,
              ),
        ),
      ],
    );
  }
}

class _InvoiceMetaRow extends StatelessWidget {
  const _InvoiceMetaRow({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: accent,
              ),
        ),
      ],
    );
  }
}

class _InvoiceActionButton extends StatelessWidget {
  const _InvoiceActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        onTap();
      },
      icon: Icon(icon, color: color, size: 18),
      label: Text(
        label,
        style: TextStyle(color: color),
      ),
    );
  }
}
