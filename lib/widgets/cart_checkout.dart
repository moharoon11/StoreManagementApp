import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/invoice_pdf_service.dart';

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
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap ?? () => openCart(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.primary.withValues(alpha: .35)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: .10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(children: [
            Badge(
              label: Text('${provider.cartCount}'),
              backgroundColor: scheme.primary,
              textColor: scheme.onPrimary,
              child: Icon(Icons.shopping_bag_outlined,
                  color: scheme.secondary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  '${provider.cartCount} item${provider.cartCount == 1 ? '' : 's'} · tap to review',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
            Text('₹${provider.cartTotal.toStringAsFixed(0)}',
                style: TextStyle(
                    color: scheme.secondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 4),
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
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(14),
            child: CartPanel(
                pageContext: context, closeOverlayOnCheckout: true),
          ),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: CartPanel(
              pageContext: context, closeOverlayOnCheckout: true),
        ),
      ),
    );
  }
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
    return Column(children: [
      Row(children: [
        Expanded(
            child: Text('Current sale',
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800))),
        IconButton(
          onPressed: provider.clearCart,
          tooltip: 'Clear cart',
          icon: Icon(Icons.delete_sweep_outlined, color: scheme.error),
        ),
      ]),
      const Divider(),
      Expanded(
        child: provider.cartItems.isEmpty
            ? Center(
                child: Text('Choose products to begin this sale.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .6))))
            : ListView.builder(
                itemCount: provider.cartItems.length,
                itemBuilder: (_, index) {
                  final item = provider.cartItems.values.elementAt(index);
                  final product = item['product'];
                  final qty = item['quantity'] as int;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(product['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    subtitle: Text('₹${product['sellingPrice']}',
                        style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: .6),
                            fontSize: 12)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        onPressed: () =>
                            provider.removeFromCart(product['id'] as int),
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            size: 20),
                      ),
                      Text('$qty',
                          style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800)),
                      IconButton(
                        onPressed: () => provider.addToCart(
                            Map<String, dynamic>.from(product as Map)),
                        icon: Icon(Icons.add_circle_outline_rounded,
                            color: scheme.primary, size: 20),
                      ),
                    ]),
                  );
                },
              ),
      ),
      const Divider(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Total',
            style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
        Text('₹${provider.cartTotal.toStringAsFixed(2)}',
            style: TextStyle(
                color: scheme.secondary,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: provider.cartItems.isEmpty || _isProcessing
              ? null
              : () => _beginCheckout(),
          icon: const Icon(Icons.lock_outline_rounded, size: 18),
          label: Text(_isProcessing
              ? 'Processing...'
              : 'Checkout ${provider.cartCount} item${provider.cartCount == 1 ? '' : 's'}'),
        ),
      ),
    ]);
  }

  void _beginCheckout() {
    if (closeOverlayOnCheckout) Navigator.of(pageContext).pop();
    showCustomerDetailsDialog(pageContext);
  }
}

/// Customer name + mobile form, then processes the checkout.
Future<void> showCustomerDetailsDialog(BuildContext context) async {
  final provider = context.read<AppProvider>();
  if (provider.cartItems.isEmpty) return;
  final scheme = Theme.of(context).colorScheme;
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final mobileController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
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
            key: formKey,
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
                  controller: nameController,
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
                  controller: mobileController,
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
                    Text('₹${provider.cartTotal.toStringAsFixed(2)}',
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
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final name = nameController.text.trim();
            final mobile = mobileController.text.trim();
            Navigator.of(dialogContext).pop();
            await processCheckout(context,
                customerName: name, customerMobile: mobile);
          },
          icon: const Icon(Icons.lock_outline_rounded, size: 18),
          label: const Text('Complete checkout'),
        ),
      ],
    ),
  );
  nameController.dispose();
  mobileController.dispose();
}

/// Posts the cart to the checkout API and shows the invoice result with
/// PDF / share / print actions.
Future<void> processCheckout(
  BuildContext context, {
  required String customerName,
  required String customerMobile,
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
      'items': items,
    });

    if (res['success'] == true) {
      final invoice = res['data'];
      provider.clearCart();
      if (!context.mounted) return;
      _showInvoiceSuccess(context, invoice);
    } else {
      messenger.showSnackBar(SnackBar(
          content:
              Text((res['message'] ?? 'Checkout failed.').toString())));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(
          'Checkout Error: ${e.toString().replaceAll('Exception: ', '')}'),
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
          Text('${(invoice['items'] as List?)?.length ?? 0} item types processed.',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .6),
                  fontSize: 12)),
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