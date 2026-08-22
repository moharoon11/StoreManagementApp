import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';

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
    
    // Check if there are valid items
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
        const SnackBar(content: Text('Please enter at least one valid item with rate and quantity.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _ManualCustomerDetailsDialog(
        total: _grandTotal,
        onCheckout: (name, mobile) {
          _processCheckout(name, mobile);
        },
      ),
    );
  }

  Future<void> _processCheckout(String name, String mobile) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      final items = <Map<String, dynamic>>[];
      for (var item in _items) {
        final rate = double.tryParse(item.rateController.text) ?? 0;
        final qty = int.tryParse(item.qtyController.text) ?? 0;
        if (rate > 0 && qty > 0) {
          items.add({
            'rate': rate,
            'quantity': qty,
          });
        }
      }

      final res = await ApiService.post(ApiConfig.manualCheckout, {
        'customerName': name,
        'customerMobileNumber': mobile,
        'items': items,
      });

      if (res['success'] == true) {
        final invoice = res['data'];
        if (!mounted) return;
        Navigator.pop(context); // close the billing view
        _showInvoiceSuccess(context, invoice);
      } else {
        messenger.showSnackBar(SnackBar(
            content: Text((res['message'] ?? 'Checkout failed.').toString())));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Checkout Error: ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: errorColor,
      ));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showInvoiceSuccess(BuildContext context, dynamic invoice) {
    final scheme = Theme.of(context).colorScheme;
    final invoiceId = invoice['id'] as int;
    final pdfFilename = 'Invoice_${invoice['invoiceNumber']}.pdf';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.check_circle, color: scheme.secondary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Checkout Completed',
                style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice #: ${invoice['invoiceNumber']}',
                style: TextStyle(
                    color: scheme.onSurface, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grand Total:',
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .6),
                        fontWeight: FontWeight.w600)),
                Text('₹${invoice['grandTotal']}',
                    style: TextStyle(
                        color: scheme.secondary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.picture_as_pdf,
                      color: scheme.error, size: 26),
                  tooltip: 'Download PDF',
                  onPressed: () async {
                    try {
                      final bytes = await InvoicePdfService.fetch(invoiceId);
                      final wasSaved =
                          await InvoicePdfService.save(bytes, pdfFilename);
                      if (ctx.mounted && wasSaved) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('PDF saved successfully.')));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error downloading PDF: $e')));
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share,
                      color: Color(0xFF25D366), size: 26),
                  tooltip: 'Share on WhatsApp',
                  onPressed: () async {
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
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error sharing PDF: $e')));
                      }
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.print, color: scheme.primary, size: 26),
                  tooltip: 'Print Invoice',
                  onPressed: () async {
                    try {
                      final bytes = await InvoicePdfService.fetch(invoiceId);
                      await Printing.layoutPdf(
                        onLayout: (format) async => bytes,
                        name: pdfFilename,
                      );
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error printing: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done',
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Normal Bill', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      body: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                SizedBox(width: 28, child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: scheme.onSurface.withValues(alpha: .6)))),
                Expanded(flex: 3, child: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: scheme.onSurface.withValues(alpha: .6)))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: scheme.onSurface.withValues(alpha: .6)))),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: scheme.onSurface.withValues(alpha: .6)))),
                const SizedBox(width: 32), // space for delete icon
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: _items.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == _items.length) {
                    return InkWell(
                      onTap: _addItem,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 18, color: scheme.primary),
                            const SizedBox(width: 4),
                            Text('Add Item', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  }

                  final item = _items[index];
                  final itemRate = double.tryParse(item.rateController.text) ?? 0;
                  final itemQty = int.tryParse(item.qtyController.text) ?? 0;
                  final itemTotal = itemRate * itemQty;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('${index + 1}.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: scheme.onSurface.withValues(alpha: .7))),
                        ),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: item.rateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              filled: true,
                              fillColor: scheme.surfaceContainerHighest.withValues(alpha: .4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: item.qtyController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              filled: true,
                              fillColor: scheme.surfaceContainerHighest.withValues(alpha: .4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            '₹${itemTotal.toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF16834B)),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: _items.length > 1
                              ? IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.close_rounded, size: 18, color: scheme.error.withValues(alpha: .7)),
                                  onPressed: () => _removeItem(index),
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Grand Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurface.withValues(alpha: .7))),
                      Text('₹${_grandTotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 44,
                    width: 140,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF365FF4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isProcessing ? null : _beginCheckout,
                      child: _isProcessing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Checkout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ManualCustomerDetailsDialog extends StatefulWidget {
  final double total;
  final void Function(String name, String mobile) onCheckout;

  const _ManualCustomerDetailsDialog({
    required this.total,
    required this.onCheckout,
  });

  @override
  State<_ManualCustomerDetailsDialog> createState() => _ManualCustomerDetailsDialogState();
}

class _ManualCustomerDetailsDialogState extends State<_ManualCustomerDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(children: [
        Icon(Icons.receipt_long_outlined, color: scheme.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Customer details',
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add these details to complete the invoice.',
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .65),
                        fontSize: 12)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Customer name (Optional)',
                    hintText: 'Enter customer name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _mobileController,
                  maxLength: 20,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: 'Customer mobile number',
                    hintText: 'e.g. +91 98765 43210',
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
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Invoice total',
                        style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700)),
                    Text('₹${widget.total.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: scheme.secondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final name = _nameController.text.trim();
            final mobile = _mobileController.text.trim();
            Navigator.of(context).pop();
            widget.onCheckout(name, mobile);
          },
          icon: const Icon(Icons.lock_outline_rounded, size: 18),
          label: const Text('Complete checkout'),
        ),
      ],
    );
  }
}
