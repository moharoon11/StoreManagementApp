import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../utils/quantity_utils.dart';

class CheckoutScreen extends StatefulWidget {
  final bool isManual;
  final List<Map<String, dynamic>>? manualItems;
  final double? manualTotal;

  const CheckoutScreen({
    Key? key,
    this.isManual = false,
    this.manualItems,
    this.manualTotal,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  late TextEditingController _amountReceivedController;
  DateTime _invoiceDate = DateTime.now();
  bool _isReceived = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    double total = 0.0;
    if (widget.isManual) {
      total = widget.manualTotal ?? 0.0;
    } else {
      final provider = Provider.of<AppProvider>(context, listen: false);
      total = provider.cartTotal;
    }
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AppProvider>();

    try {
      final customerName = _nameController.text.trim();
      final customerMobile = _mobileController.text.trim();
      // Send a date-only value. This avoids a timezone shift changing the
      // invoice day between the phone and the API server.
      final invoiceDate = DateFormat('yyyy-MM-dd').format(_invoiceDate);

      double grandTotal = 0.0;
      if (widget.isManual) {
        grandTotal = widget.manualTotal ?? 0.0;
      } else {
        grandTotal = provider.cartTotal;
      }

      final recAmount = double.tryParse(_amountReceivedController.text) ??
          (_isReceived ? grandTotal : 0.0);

      Map<String, dynamic> response;
      if (widget.isManual) {
        response = await ApiService.post(ApiConfig.manualCheckout, {
          'customerName': customerName,
          'customerMobileNumber': customerMobile,
          'isReceived': _isReceived,
          'amountReceived': recAmount,
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
          'amountReceived': recAmount,
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
        Navigator.pop(context); // close CheckoutScreen
        _showInvoiceSuccessDialog(context, invoice, _invoiceDate);
      } else {
        messenger.showSnackBar(
          SnackBar(
              content:
                  Text((response['message'] ?? 'Checkout failed.').toString())),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Checkout Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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

  void _showInvoiceSuccessDialog(
      BuildContext context, dynamic invoice, DateTime invoiceDate) {
    final scheme = Theme.of(context).colorScheme;
    final invoiceId = invoice['id'] as int;
    final pdfFilename = 'Invoice_${invoice['invoiceNumber']}.pdf';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
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
            const SizedBox(height: 4),
            Text(
                'Invoice date: ${DateFormat('dd MMM yyyy').format(invoiceDate)}',
                style: const TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total:',
                    style: TextStyle(
                        color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                Text('₹${invoice['grandTotal']}',
                    style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Balance Due:',
                    style: TextStyle(
                        color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                Text('₹${invoice['balanceDue'] ?? '0.00'}',
                    style: TextStyle(
                      color:
                          ((invoice['balanceDue'] as num?)?.toDouble() ?? 0) > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf,
                      color: Color(0xFFEF4444), size: 26),
                  tooltip: 'Download PDF',
                  onPressed: () async {
                    try {
                      final bytes = await InvoicePdfService.fetch(invoiceId);
                      final wasSaved =
                          await InvoicePdfService.save(bytes, pdfFilename);
                      if (ctx.mounted && wasSaved) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('PDF saved successfully.')));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Error downloading PDF: $e')));
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share,
                      color: Color(0xFF25D366), size: 26),
                  tooltip: 'Share PDF',
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
                  icon: const Icon(Icons.print,
                      color: Color(0xFF2563EB), size: 26),
                  tooltip: 'Print Invoice',
                  onPressed: () async {
                    try {
                      final bytes = await InvoicePdfService.fetch(invoiceId);
                      await Printing.layoutPdf(
                          onLayout: (format) async => bytes, name: pdfFilename);
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
            child: const Text('Done',
                style: TextStyle(
                    color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double grandTotal = 0.0;
    List<Map<String, dynamic>> itemsList = [];

    if (widget.isManual) {
      grandTotal = widget.manualTotal ?? 0.0;
      itemsList = widget.manualItems ?? [];
    } else {
      final provider = Provider.of<AppProvider>(context);
      grandTotal = provider.cartTotal;
      itemsList = provider.cartItems.values.map((item) {
        final product = item['product'];
        final qty = quantityValue(item['quantity']);
        final price = (product['sellingPrice'] as num).toDouble();
        return {
          'name': product['name'] ?? '',
          'price': price,
          'qty': qty,
          'unit': productUnit(product),
          'total': price * qty,
        };
      }).toList();
    }

    final amtRec = double.tryParse(_amountReceivedController.text) ??
        (_isReceived ? grandTotal : 0.0);
    final balanceDue = (grandTotal - amtRec).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Checkout & Payment',
          style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Information Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Customer Details',
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Customer Name (Optional)',
                                hintText: 'e.g. Ishak',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Customer Mobile Number *',
                                hintText: 'e.g. 9360984711',
                                prefixIcon: Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                              validator: (value) {
                                final mobile = (value ?? '').trim();
                                if (mobile.isEmpty)
                                  return 'Customer mobile number is required.';
                                if (!RegExp(r'^[0-9+\-\s()]{7,20}$')
                                    .hasMatch(mobile)) {
                                  return 'Enter a valid mobile number.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Semantics(
                              button: true,
                              label:
                                  'Invoice date: ${DateFormat('dd MMMM yyyy').format(_invoiceDate)}',
                              child: InkWell(
                                onTap: _selectInvoiceDate,
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Invoice Date',
                                    prefixIcon:
                                        Icon(Icons.calendar_today_outlined),
                                    suffixIcon:
                                        Icon(Icons.edit_calendar_outlined),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                  ),
                                  child: Text(
                                    DateFormat('dd MMM yyyy')
                                        .format(_invoiceDate),
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Billed Items Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: const BoxDecoration(
                                color: Color(0xFF60A5FA),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(11)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Billed Items (${itemsList.length})',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            ...itemsList.asMap().entries.map((entry) {
                              final idx = entry.key + 1;
                              final item = entry.value;
                              final name = widget.isManual
                                  ? 'Manual Item #$idx'
                                  : (item['name'] ?? '');
                              final price = widget.isManual
                                  ? ((item['rate'] as num).toDouble())
                                  : ((item['price'] as num).toDouble());
                              final qty = quantityValue(
                                  item['quantity'] ?? item['qty']);
                              final unit = widget.isManual
                                  ? ''
                                  : ' ${item['unit'] ?? 'Piece'}';
                              final total = price * qty;

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  border: Border(
                                      bottom:
                                          BorderSide(color: Color(0xFFF1F5F9))),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('#$idx',
                                          style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: const TextStyle(
                                                  color: Color(0xFF0F172A),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)),
                                          Text(
                                              '${formatQuantity(qty)}$unit × ₹${price.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Text('₹${total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Payment Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Amount',
                                    style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text('₹${grandTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Checkbox(
                                  value: _isReceived,
                                  activeColor: const Color(0xFF2563EB),
                                  onChanged: (val) {
                                    setState(() {
                                      _isReceived = val ?? true;
                                      if (_isReceived) {
                                        _amountReceivedController.text =
                                            grandTotal.toStringAsFixed(2);
                                      } else {
                                        _amountReceivedController.text = '0.00';
                                      }
                                    });
                                  },
                                ),
                                const Text('Received',
                                    style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const Spacer(),
                                SizedBox(
                                  width: 130,
                                  child: TextField(
                                    controller: _amountReceivedController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      prefixText: '₹ ',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Balance Due',
                                    style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(
                                  '₹${balanceDue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: balanceDue > 0
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Sticky Checkout Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _completeCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isProcessing
                        ? 'Processing Checkout...'
                        : 'Complete Checkout',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
