import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class PosCheckoutView extends StatefulWidget {
  const PosCheckoutView({Key? key}) : super(key: key);

  @override
  State<PosCheckoutView> createState() => _PosCheckoutViewState();
}

class _PosCheckoutViewState extends State<PosCheckoutView> {
  bool _isLoading = true;
  bool _isCheckingOut = false;
  List<dynamic> _products = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchAvailableProducts();
  }

  Future<void> _fetchAvailableProducts() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(ApiConfig.products,
          queryParameters: {'pageSize': '100'});
      if (res['success'] == true) {
        setState(() {
          _products = res['data']['items'] ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processCheckout(AppProvider provider) async {
    if (provider.cartItems.isEmpty) return;

    setState(() => _isCheckingOut = true);
    try {
      final items = provider.cartItems.values.map((item) {
        return {
          'productId': item['product']['id'],
          'quantity': item['quantity'],
        };
      }).toList();

      final res = await ApiService.post(ApiConfig.checkout, {'items': items});

      if (res['success'] == true && mounted) {
        final invoice = res['data'];
        provider.clearCart();
        _fetchAvailableProducts();

        final pdfUrl = '${ApiConfig.baseUrl}/invoices/${invoice['id']}/pdf';

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: Color(0xFF12A594), size: 24),
                  SizedBox(width: 8),
                  Text('Checkout Completed',
                      style: TextStyle(
                          color: Color(0xFF172033),
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ],
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice #: ${invoice['invoiceNumber']}',
                    style: const TextStyle(
                        color: Color(0xFF172033), fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total:',
                        style: TextStyle(
                            color: Color(0xFF6C7486),
                            fontWeight: FontWeight.w600)),
                    Text('₹${invoice['grandTotal']}',
                        style: const TextStyle(
                            color: Color(0xFF12A594),
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    '${(invoice['items'] as List?)?.length ?? 0} item types processed.',
                    style: const TextStyle(
                        color: Color(0xFF6C7486), fontSize: 13)),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE6E8EF)),
                const SizedBox(height: 8),
                // Actions: Download PDF, Share WhatsApp, Print
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // PDF Download / Print
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf,
                          color: Color(0xFFE75C5C), size: 28),
                      tooltip: 'Download PDF',
                      onPressed: () async {
                        try {
                          final res = await http.get(Uri.parse(pdfUrl));
                          if (res.statusCode == 200) {
                            await Printing.layoutPdf(
                                onLayout: (format) async => res.bodyBytes,
                                name:
                                    'Invoice_${invoice['invoiceNumber']}.pdf');
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Error loading PDF: $e')));
                          }
                        }
                      },
                    ),
                    // WhatsApp Share
                    IconButton(
                      icon: const Icon(Icons.share,
                          color: Color(0xFF25D366), size: 28),
                      tooltip: 'Share on WhatsApp',
                      onPressed: () async {
                        final text = Uri.encodeComponent(
                            "Invoice #${invoice['invoiceNumber']} - Total: ₹${invoice['grandTotal']}\nPDF: $pdfUrl");
                        final waUri = Uri.parse("https://wa.me/?text=$text");
                        try {
                          await launchUrl(waUri,
                              mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      },
                    ),
                    // Print Invoice
                    IconButton(
                      icon: const Icon(Icons.print,
                          color: Color(0xFF365FF4), size: 28),
                      tooltip: 'Print Invoice',
                      onPressed: () async {
                        try {
                          final res = await http.get(Uri.parse(pdfUrl));
                          if (res.statusCode == 200) {
                            await Printing.layoutPdf(
                                onLayout: (format) async => res.bodyBytes,
                                name:
                                    'Invoice_${invoice['invoiceNumber']}.pdf');
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
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
                        color: Color(0xFF365FF4), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Checkout Error: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: const Color(0xFFE75C5C)),
        );
      }
    }
    setState(() => _isCheckingOut = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    final filteredProducts = _products.where((p) {
      final name = (p['name'] as String).toLowerCase();
      final cat = (p['categoryName'] as String? ?? '').toLowerCase();
      final search = _searchTerm.toLowerCase();
      return name.contains(search) || cat.contains(search);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;

        Widget productListSection = Column(
          children: [
            TextField(
              style: const TextStyle(color: Color(0xFF172033)),
              onChanged: (val) => setState(() => _searchTerm = val),
              decoration: const InputDecoration(
                hintText: 'Search product to add to bill...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF365FF4)),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF365FF4)))
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isWide ? 190 : 150,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final p = filteredProducts[index];
                        final stock = p['stockQuantity'] as int;
                        final isInCart =
                            provider.cartItems.containsKey(p['id']);

                        return InkWell(
                          onTap: stock > 0 ? () => provider.addToCart(p) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isInCart
                                    ? const Color(0xFF365FF4)
                                    : const Color(0xFFE6E8EF),
                                width: isInCart ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF172033),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                const Spacer(),
                                Text('₹${p['sellingPrice']}',
                                    style: const TextStyle(
                                        color: Color(0xFF12A594),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Stock: $stock',
                                        style: TextStyle(
                                            color: stock > 0
                                                ? const Color(0xFF6C7486)
                                                : const Color(0xFFE75C5C),
                                            fontSize: 11)),
                                    const Icon(Icons.add_shopping_cart,
                                        color: Color(0xFF365FF4), size: 18),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );

        Widget cartSection = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6E8EF)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Current Invoice',
                      style: TextStyle(
                          color: Color(0xFF172033),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined,
                        color: Color(0xFFE75C5C)),
                    onPressed: provider.clearCart,
                    tooltip: 'Clear Cart',
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE6E8EF)),
              Expanded(
                child: provider.cartItems.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.shopping_cart_outlined,
                                size: 40, color: Color(0xFFA1A8B7)),
                            SizedBox(height: 8),
                            Text('Tap products to add to bill.',
                                style: TextStyle(
                                    color: Color(0xFF6C7486), fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: provider.cartItems.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFF2F3F8)),
                        itemBuilder: (context, index) {
                          final item =
                              provider.cartItems.values.toList()[index];
                          final product = item['product'];
                          final qty = item['quantity'] as int;
                          final availableStock =
                              (product['stockQuantity'] as int? ?? 9999);
                          final price =
                              (product['sellingPrice'] as num).toDouble();
                          final total = price * qty;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'] ?? '',
                                        style: const TextStyle(
                                          color: Color(0xFF172033),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${price.toStringAsFixed(2)} × $qty = ₹${total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF12A594),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => provider
                                          .removeFromCart(product['id']),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3D6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.remove,
                                            color: Color(0xFFBD781D), size: 16),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Text(
                                        '$qty',
                                        style: const TextStyle(
                                          color: Color(0xFF172033),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: qty < availableStock
                                          ? () => provider.addToCart(product)
                                          : () {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Cannot add more. Max stock available: $availableStock'),
                                                  duration: const Duration(
                                                      seconds: 1),
                                                ),
                                              );
                                            },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: qty < availableStock
                                              ? const Color(0xFFE6EDFF)
                                              : const Color(0xFFF2F3F8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          color: qty < availableStock
                                              ? const Color(0xFF365FF4)
                                              : const Color(0xFFA1A8B7),
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(color: Color(0xFFE6E8EF)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total:',
                      style: TextStyle(
                          color: Color(0xFF172033),
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text('₹${provider.cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Color(0xFF12A594),
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: provider.cartItems.isEmpty || _isCheckingOut
                      ? null
                      : () => _processCheckout(provider),
                  icon: const Icon(Icons.point_of_sale, size: 18),
                  label: _isCheckingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Checkout (${provider.cartCount} items)',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF12A594),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: productListSection),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: cartSection),
              ],
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(flex: 3, child: productListSection),
                const SizedBox(height: 14),
                Expanded(flex: 2, child: cartSection),
              ],
            ),
          );
        }
      },
    );
  }
}
