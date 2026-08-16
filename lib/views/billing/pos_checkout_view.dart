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

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 860;
      final products = Column(children: [
        TextField(
            onChanged: (value) => setState(() => _searchTerm = value),
            decoration: const InputDecoration(
                hintText: 'Search and add products',
                prefixIcon: Icon(Icons.search_rounded))),
        const SizedBox(height: 16),
        Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _productGrid(filteredProducts, provider, wide))
      ]);
      return Padding(
          padding: EdgeInsets.all(wide ? 28 : 16),
          child: wide
              ? Row(children: [
                  Expanded(flex: 3, child: products),
                  const SizedBox(width: 22),
                  SizedBox(width: 360, child: _cartPanel(provider))
                ])
              : Column(children: [
                  Expanded(child: products),
                  const SizedBox(height: 12),
                  _cartBar(provider)
                ]));
    });
  }

  Widget _productGrid(List<dynamic> products, AppProvider provider, bool wide) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: wide ? 220 : 165,
          childAspectRatio: 1.12,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12),
      itemCount: products.length,
      itemBuilder: (_, index) {
        final product = products[index];
        final stock = product['stockQuantity'] as int? ?? 0;
        final inCart = provider.cartItems.containsKey(product['id']);
        return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
                onTap: stock > 0 ? () => provider.addToCart(product) : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: inCart
                                ? const Color(0xFF365FF4)
                                : const Color(0xFFE6E8EF),
                            width: inCart ? 2 : 1),
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product['categoryName'] ?? 'PRODUCT',
                              style: const TextStyle(
                                  color: Color(0xFF365FF4),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text(product['name'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF172033),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                          const Spacer(),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('₹${product['sellingPrice']}',
                                    style: const TextStyle(
                                        color: Color(0xFF12A594),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16)),
                                Icon(
                                    inCart
                                        ? Icons.check_circle_rounded
                                        : Icons.add_circle_outline_rounded,
                                    color: stock > 0
                                        ? const Color(0xFF365FF4)
                                        : const Color(0xFFA1A8B7))
                              ]),
                          const SizedBox(height: 4),
                          Text(stock > 0 ? '$stock available' : 'Out of stock',
                              style: TextStyle(
                                  color: stock > 0
                                      ? const Color(0xFF6C7486)
                                      : const Color(0xFFE75C5C),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600))
                        ]))));
      },
    );
  }

  Widget _cartBar(AppProvider provider) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
          onTap: () => _openCart(provider),
          borderRadius: BorderRadius.circular(18),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE6E8EF)),
                  borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                const Icon(Icons.shopping_bag_outlined,
                    color: Color(0xFF12A594)),
                const SizedBox(width: 11),
                Expanded(
                    child: Text('${provider.cartCount} items · tap to review',
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                Text('₹${provider.cartTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Color(0xFF12A594),
                        fontSize: 20,
                        fontWeight: FontWeight.w800))
              ]))));

  void _openCart(AppProvider provider) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _cartPanel(provider))));

  Widget _cartPanel(AppProvider provider) {
    return Column(children: [
      Row(children: [
        const Expanded(
            child: Text('Current sale',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        IconButton(
            onPressed: provider.clearCart,
            icon: const Icon(Icons.delete_sweep_outlined,
                color: Color(0xFFE75C5C)))
      ]),
      const Divider(),
      Expanded(
          child: provider.cartItems.isEmpty
              ? const Center(child: Text('Choose products to begin this sale.'))
              : ListView.builder(
                  itemCount: provider.cartItems.length,
                  itemBuilder: (_, index) {
                    final item = provider.cartItems.values.elementAt(index);
                    final product = item['product'];
                    final qty = item['quantity'] as int;
                    return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(product['name'] ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('₹${product['sellingPrice']}'),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              onPressed: () =>
                                  provider.removeFromCart(product['id']),
                              icon: const Icon(
                                  Icons.remove_circle_outline_rounded)),
                          Text('$qty'),
                          IconButton(
                              onPressed: () => provider.addToCart(product),
                              icon: const Icon(Icons.add_circle_outline_rounded,
                                  color: Color(0xFF365FF4)))
                        ]));
                  })),
      const Divider(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Total',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text('₹${provider.cartTotal.toStringAsFixed(2)}',
            style: const TextStyle(
                color: Color(0xFF12A594),
                fontWeight: FontWeight.w800,
                fontSize: 23))
      ]),
      const SizedBox(height: 12),
      SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: provider.cartItems.isEmpty || _isCheckingOut
                  ? null
                  : () => _processCheckout(provider),
              icon: const Icon(Icons.lock_outline_rounded),
              label: Text(_isCheckingOut
                  ? 'Processing...'
                  : 'Checkout ${provider.cartCount} items'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF12A594))))
    ]);
  }
}
