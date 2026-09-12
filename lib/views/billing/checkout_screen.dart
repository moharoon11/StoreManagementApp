import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';

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
          backgroundColor: const Color(0xFFB42318),
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
    final balanceDue =
        ((invoice['balanceDue'] as num?)?.toDouble() ?? 0).clamp(0, double.infinity);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.check_circle, color: scheme.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Checkout completed',
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
            LedgerTag(
              label: 'Invoice #${invoice['invoiceNumber']}',
              color: scheme.primary,
              icon: Icons.receipt_long_outlined,
            ),
            const SizedBox(height: 8),
            Text('Invoice date: ${DateFormat('dd MMM yyyy').format(invoiceDate)}',
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grand total',
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .6),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text('₹${invoice['grandTotal']}',
                    style: TextStyle(
                        color: scheme.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Balance due',
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .6),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text('₹${invoice['balanceDue'] ?? '0.00'}',
                    style: TextStyle(
                      color: balanceDue > 0 ? scheme.error : scheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.download_outlined, color: scheme.error, size: 24),
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
                  icon: const Icon(Icons.share, color: Color(0xFF157347), size: 24),
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
                  icon: Icon(Icons.print, color: scheme.primary, size: 24),
                  tooltip: 'Print invoice',
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
            child: const Text('Done'),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Checkout & payment',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _customerCard(),
                          const SizedBox(height: 12),
                          _itemsCard(itemsList),
                          const SizedBox(height: 12),
                          _paymentCard(grandTotal, balanceDue),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _customerCard() {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      accent: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const LedgerKicker('Customer'),
        const SizedBox(height: 10),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Customer name (optional)',
            prefixIcon: Icon(Icons.person_outline),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Customer mobile number *',
            prefixIcon: Icon(Icons.phone_outlined),
            isDense: true,
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
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label:
              'Invoice date: ${DateFormat('dd MMMM yyyy').format(_invoiceDate)}',
          child: InkWell(
            onTap: _selectInvoiceDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Invoice date',
                prefixIcon: Icon(Icons.calendar_today_outlined),
                isDense: true,
              ),
              child: Text(
                DateFormat('dd MMM yyyy').format(_invoiceDate),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _itemsCard(List<Map<String, dynamic>> itemsList) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      accent: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: LedgerKicker('Billed items')),
          LedgerTag(label: '${itemsList.length}', color: scheme.primary),
        ]),
        const SizedBox(height: 6),
        if (itemsList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No items on this bill.',
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .5),
                    fontSize: 12)),
          )
        else
          for (var i = 0; i < itemsList.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            _itemRow(i, itemsList[i]),
          ],
      ]),
    );
  }

  Widget _itemRow(int index, Map<String, dynamic> item) {
    final scheme = Theme.of(context).colorScheme;
    final idx = index + 1;
    final name = widget.isManual ? 'Manual Item #$idx' : (item['name'] ?? '');
    final price = widget.isManual
        ? ((item['rate'] as num).toDouble())
        : ((item['price'] as num).toDouble());
    final qty = quantityValue(item['quantity'] ?? item['qty']);
    final unit = widget.isManual ? '' : ' ${item['unit'] ?? 'Piece'}';
    final total = price * qty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('$idx',
              style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5)),
            const SizedBox(height: 2),
            Text('${formatQuantity(qty)}$unit × ₹${price.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .55),
                    fontSize: 11.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Text('₹${total.toStringAsFixed(2)}',
            style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 13.5)),
      ]),
    );
  }

  Widget _paymentCard(double grandTotal, double balanceDue) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      accent: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: LedgerKicker('Payment')),
          Text('₹${grandTotal.toStringAsFixed(2)}',
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 8),
        Row(children: [
          Checkbox(
            value: _isReceived,
            activeColor: scheme.primary,
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
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          Expanded(
            child: TextField(
              controller: _amountReceivedController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                isDense: true,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Balance due',
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .6),
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            Text('₹${balanceDue.toStringAsFixed(2)}',
                style: TextStyle(
                  color: balanceDue > 0 ? scheme.error : scheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                )),
          ],
        ),
      ]),
    );
  }

  Widget _bottomBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _isProcessing ? null : _completeCheckout,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline, size: 20),
            label: Text(
              _isProcessing ? 'Processing checkout...' : 'Complete checkout',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}