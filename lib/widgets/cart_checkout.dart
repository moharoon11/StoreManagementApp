import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/invoice_pdf_service.dart';
import '../views/billing/checkout_screen.dart';
import '../utils/quantity_utils.dart';
import 'workspace_ui.dart';

/// Shared cart + checkout building blocks used by both the Sell page and the
/// Categories page, so every entry point offers the identical billing flow.

bool _isProcessing = false;

/// Compact tappable bar that appears whenever the cart has items.
/// Tap it to review the cart and check out.
class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (provider.cartItems.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap ?? () => openCart(context),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.primary.withValues(alpha: .24)),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: .08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Badge(
                  label: Text(formatQuantity(provider.cartCount)),
                  backgroundColor: scheme.primary,
                  textColor: scheme.onPrimary,
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current sale',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatQuantity(provider.cartCount)} item${provider.cartCount == 1 ? '' : 's'} ready for checkout',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: .62),
                        ),
                  ),
                ],
              ),
            ),
            Text(
              '₹${provider.cartTotal.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: scheme.onSurface.withValues(alpha: .5)),
          ]),
        ),
      ),
    );
  }
}

/// Opens the cart for review — bottom sheet on narrow screens, centered
/// dialog on wide ones.
Future<void> openCart(BuildContext context) async {
  final provider = context.read<AppProvider>();
  if (provider.cartItems.isEmpty) return;
  final wide = MediaQuery.sizeOf(context).width >= 900;
  if (wide) {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470, maxHeight: 640),
          child: CartPanel(pageContext: context, closeOverlayOnCheckout: true),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: CartPanel(pageContext: context, closeOverlayOnCheckout: true),
        ),
      ),
    );
  }
}

Future<void> _editCartQuantity(BuildContext context, AppProvider provider,
    Map<String, dynamic> product, double currentQuantity) async {
  final unit = productUnit(product);
  final stock = quantityValue(product['stockQuantity']);
  // Return the new value from the dialog before notifying the cart provider.
  // Updating the provider while this route is being removed can rebuild the
  // bottom sheet beneath it with active inherited dependents still attached.
  final selectedQuantity = await showDialog<double>(
    context: context,
    builder: (_) => _CartQuantityDialog(
      unit: unit,
      stock: stock,
      initialQuantity: currentQuantity,
    ),
  );
  if (selectedQuantity != null) {
    provider.setCartQuantity(product['id'] as int, selectedQuantity);
  }
}

/// Owns its controller for the entire lifetime of the route. Disposing an
/// externally-created controller immediately after Navigator.pop can race the
/// dialog's exit animation and leave the TextField with a disposed controller.
class _CartQuantityDialog extends StatefulWidget {
  const _CartQuantityDialog({
    required this.unit,
    required this.stock,
    required this.initialQuantity,
  });

  final String unit;
  final double stock;
  final double initialQuantity;

  @override
  State<_CartQuantityDialog> createState() => _CartQuantityDialogState();
}

class _CartQuantityDialogState extends State<_CartQuantityDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: formatQuantity(widget.initialQuantity));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final quantity = double.tryParse(_controller.text);
    if (quantity == null || quantity <= 0 || quantity > widget.stock) {
      setState(() {
        _errorText = 'Enter a quantity from 0.001 to '
            '${formatQuantity(widget.stock)} ${widget.unit}.';
      });
      return;
    }
    Navigator.pop(context, quantity);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Quantity (${widget.unit})'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) {
            if (_errorText != null) setState(() => _errorText = null);
          },
          decoration: InputDecoration(
            labelText: 'Quantity',
            helperText:
                'Available: ${formatQuantity(widget.stock)} ${widget.unit}',
            errorText: _errorText,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      );
}

/// Full cart contents: line items with quantity controls, total and the
/// checkout button.
class CartPanel extends StatelessWidget {
  const CartPanel({
    super.key,
    required this.pageContext,
    this.closeOverlayOnCheckout = false,
  });

  /// Context of the page underneath any sheet/dialog. Used to present the
  /// checkout dialogs after the cart overlay closes.
  final BuildContext pageContext;

  /// Whether the cart is shown inside an overlay that should be closed
  /// before starting checkout. Leave false when embedded inline in a page.
  final bool closeOverlayOnCheckout;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          return Column(children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current sale', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Review the basket before checkout.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: .62),
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: provider.clearCart,
                tooltip: 'Clear cart',
                style: IconButton.styleFrom(
                  backgroundColor: scheme.error.withValues(alpha: .10),
                ),
                icon: Icon(Icons.delete_sweep_outlined, color: scheme.error),
              ),
            ]),
            const SizedBox(height: 16),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 16),
            Expanded(
              child: provider.cartItems.isEmpty
                  ? const EmptyCanvas(
                      icon: Icons.shopping_bag_outlined,
                      title: 'No items in the current sale',
                      detail: 'Add products from the catalogue to start checkout.',
                    )
                  : ListView.separated(
                      itemCount: provider.cartItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final item = provider.cartItems.values.elementAt(index);
                        final product =
                            Map<String, dynamic>.from(item['product'] as Map);
                        final qty = quantityValue(item['quantity']);
                        return _CartLine(
                          product: product,
                          quantity: qty,
                          compact: compact,
                          onDecrease: () =>
                              provider.removeFromCart(product['id'] as int),
                          onIncrease: () => provider.addToCart(product),
                          onEdit: () =>
                              _editCartQuantity(context, provider, product, qty),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total', style: Theme.of(context).textTheme.titleMedium),
              Text(
                '₹${provider.cartTotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.primary,
                    ),
              ),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: provider.cartItems.isEmpty || _isProcessing
                    ? null
                    : () => _beginCheckout(),
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text(
                  _isProcessing
                      ? 'Processing...'
                      : 'Checkout ${formatQuantity(provider.cartCount)} item${provider.cartCount == 1 ? '' : 's'}',
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  void _beginCheckout() {
    if (closeOverlayOnCheckout) Navigator.of(pageContext).pop();
    Navigator.of(pageContext).push(
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.product,
    required this.quantity,
    required this.compact,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEdit,
  });

  final Map<String, dynamic> product;
  final double quantity;
  final bool compact;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controls = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrease,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          TextButton(
            onPressed: onEdit,
            child: Text(
              formatProductQuantity(quantity, product),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            onPressed: onIncrease,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.add_rounded,
              size: 18,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (product['name'] ?? '').toString(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${product['sellingPrice']} · ${productUnit(product)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: .62),
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: controls),
                    const SizedBox(width: 12),
                    Text(
                      '₹${((product['sellingPrice'] as num).toDouble() * quantity).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (product['name'] ?? '').toString(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${product['sellingPrice']} · ${productUnit(product)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: .62),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                controls,
              ],
            ),
    );
  }
}

/// Customer name + mobile form, then processes the checkout.
Future<void> showCustomerDetailsDialog(BuildContext context) async {
  final provider = context.read<AppProvider>();
  if (provider.cartItems.isEmpty) return;

  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CheckoutScreen()),
  );
}

class _CustomerDetailsDialog extends StatefulWidget {
  const _CustomerDetailsDialog({required this.pageContext});
  final BuildContext pageContext;

  @override
  State<_CustomerDetailsDialog> createState() => _CustomerDetailsDialogState();
}

class _CustomerDetailsDialogState extends State<_CustomerDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _amountReceivedController = TextEditingController();
  bool _isReceived = true;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _amountReceivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.pageContext.read<AppProvider>();
    final scheme = Theme.of(context).colorScheme;
    final total = provider.cartTotal;
    final amountRec = double.tryParse(_amountReceivedController.text) ??
        (_isReceived ? total : 0.0);
    final balanceDue = (total - amountRec).clamp(0.0, double.infinity);

    return AlertDialog(
      title: Row(children: [
        Icon(Icons.receipt_long_outlined, color: scheme.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Customer details & Payment',
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
                Text('Add details to complete sale & record balance due.',
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
                  decoration: const InputDecoration(
                    labelText: 'Customer Name (Optional)',
                    hintText: 'e.g. Ishak',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _mobileController,
                  maxLength: 20,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Customer Mobile Number',
                    hintText: 'e.g. 9360984711',
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outlineVariant),
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
                                  fontSize: 14)),
                          Text('₹${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: _isReceived,
                            activeColor: scheme.primary,
                            onChanged: (val) {
                              setState(() {
                                _isReceived = val ?? true;
                                if (_isReceived) {
                                  _amountReceivedController.text =
                                      total.toStringAsFixed(2);
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
                                  fontSize: 14)),
                          const Spacer(),
                          SizedBox(
                            width: 110,
                            height: 38,
                            child: TextField(
                              controller: _amountReceivedController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              onChanged: (v) => setState(() {}),
                              decoration: const InputDecoration(
                                prefixText: '₹',
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Balance Due',
                              style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text(
                            '₹${balanceDue.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: balanceDue > 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
          onPressed: () async {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final name = _nameController.text.trim();
            final mobile = _mobileController.text.trim();
            final recAmount = double.tryParse(_amountReceivedController.text) ??
                (_isReceived ? total : 0.0);

            Navigator.of(context).pop();
            await processCheckout(
              widget.pageContext,
              customerName: name,
              customerMobile: mobile,
              isReceived: _isReceived,
              amountReceived: recAmount,
            );
          },
          icon: const Icon(Icons.lock_outline_rounded, size: 18),
          label: const Text('Complete Checkout'),
        ),
      ],
    );
  }
}

/// Posts the cart to the checkout API and shows the invoice result with
/// PDF / share / print actions.
Future<void> processCheckout(
  BuildContext context, {
  required String customerName,
  required String customerMobile,
  bool isReceived = true,
  double? amountReceived,
}) async {
  final provider = context.read<AppProvider>();
  if (provider.cartItems.isEmpty || _isProcessing) return;
  _isProcessing = true;
  final messenger = ScaffoldMessenger.of(context);
  final errorColor = Theme.of(context).colorScheme.error;
  try {
    final items = provider.cartItems.values.map((item) {
      return {
        'productId': item['product']['id'],
        'quantity': item['quantity'],
      };
    }).toList();

    final res = await ApiService.post(ApiConfig.checkout, {
      'customerName': customerName,
      'customerMobileNumber': customerMobile,
      'isReceived': isReceived,
      'amountReceived': amountReceived,
      'items': items,
    });

    if (res['success'] == true) {
      final invoice = res['data'];
      provider.clearCart();
      if (!context.mounted) return;
      _showInvoiceSuccess(context, invoice);
    } else {
      messenger.showSnackBar(SnackBar(
          content: Text((res['message'] ?? 'Checkout failed.').toString())));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content:
          Text('Checkout Error: ${e.toString().replaceAll('Exception: ', '')}'),
      backgroundColor: errorColor,
    ));
  } finally {
    _isProcessing = false;
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
          const SizedBox(height: 8),
          Text(
              '${(invoice['items'] as List?)?.length ?? 0} item types processed.',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .6), fontSize: 12)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.picture_as_pdf, color: scheme.error, size: 26),
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
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error downloading PDF: $e')));
                    }
                  }
                },
              ),
              IconButton(
                icon:
                    const Icon(Icons.share, color: Color(0xFF25D366), size: 26),
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
