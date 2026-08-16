import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../config/api_config.dart';

class PosCheckoutView extends StatefulWidget {
  const PosCheckoutView({Key? key}) : super(key: key);

  @override
  State<PosCheckoutView> createState() => _PosCheckoutViewState();
}

class _PosCheckoutViewState extends State<PosCheckoutView> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isCheckingOut = false;
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  String _searchTerm = '';
  int? _selectedCategoryId;
  int _currentPage = 1;
  bool _hasMore = true;
  Timer? _searchDebounce;
  final ScrollController _productsController = ScrollController();

  static const _pageSize = 36;

  @override
  void initState() {
    super.initState();
    _productsController.addListener(_loadMoreWhenNeeded);
    _loadCatalogue();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _productsController
      ..removeListener(_loadMoreWhenNeeded)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadCatalogue() async {
    await Future.wait(
        [_fetchCategories(), _fetchAvailableProducts(reset: true)]);
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await ApiService.get(ApiConfig.categories);
      if (res['success'] == true && mounted) {
        setState(() => _categories = res['data'] ?? []);
      }
    } catch (_) {
      // Selling can still continue without category filters.
    }
  }

  void _loadMoreWhenNeeded() {
    if (_productsController.hasClients &&
        _productsController.position.extentAfter < 360) {
      _fetchAvailableProducts();
    }
  }

  Future<void> _fetchAvailableProducts({bool reset = false}) async {
    if (_isLoadingMore || (!reset && (!_hasMore || _isLoading))) return;
    final nextPage = reset ? 1 : _currentPage + 1;
    setState(() {
      if (reset) {
        _isLoading = true;
        _hasMore = true;
      } else {
        _isLoadingMore = true;
      }
    });
    try {
      final params = <String, String>{
        'pageNumber': '$nextPage',
        'pageSize': '$_pageSize',
      };
      if (_searchTerm.trim().isNotEmpty)
        params['searchTerm'] = _searchTerm.trim();
      if (_selectedCategoryId != null) {
        params['categoryId'] = _selectedCategoryId.toString();
      }
      final res =
          await ApiService.get(ApiConfig.products, queryParameters: params);
      if (res['success'] == true && mounted) {
        final page = res['data'] as Map<String, dynamic>;
        final items = (page['items'] as List?) ?? [];
        setState(() {
          _products = reset ? items : [..._products, ...items];
          _currentPage = nextPage;
          _hasMore = items.length >= _pageSize;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _setSearch(String value) {
    _searchTerm = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchAvailableProducts(reset: true);
    });
  }

  void _selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    setState(() => _selectedCategoryId = categoryId);
    _fetchAvailableProducts(reset: true);
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
        _fetchAvailableProducts(reset: true);

        final invoiceId = invoice['id'] as int;
        final pdfFilename = 'Invoice_${invoice['invoiceNumber']}.pdf';

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
                    // PDF download
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf,
                          color: Color(0xFFE75C5C), size: 28),
                      tooltip: 'Download PDF',
                      onPressed: () async {
                        try {
                          final bytes =
                              await InvoicePdfService.fetch(invoiceId);
                          final wasSaved =
                              await InvoicePdfService.save(bytes, pdfFilename);
                          if (mounted && wasSaved) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('PDF saved successfully.')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Error downloading PDF: $e')));
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
                        try {
                          final bytes =
                              await InvoicePdfService.fetch(invoiceId);
                          await Printing.sharePdf(
                            bytes: bytes,
                            filename: pdfFilename,
                            subject: 'Invoice ${invoice['invoiceNumber']}',
                            body:
                                'Invoice #${invoice['invoiceNumber']} - Total: ₹${invoice['grandTotal']}',
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error sharing PDF: $e')),
                            );
                          }
                        }
                      },
                    ),
                    // Print Invoice
                    IconButton(
                      icon: const Icon(Icons.print,
                          color: Color(0xFF365FF4), size: 28),
                      tooltip: 'Print Invoice',
                      onPressed: () async {
                        try {
                          final bytes =
                              await InvoicePdfService.fetch(invoiceId);
                          await Printing.layoutPdf(
                            onLayout: (format) async => bytes,
                            name: pdfFilename,
                          );
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

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 860;
      final products = Column(children: [
        TextField(
            onChanged: _setSearch,
            decoration: const InputDecoration(
                hintText: 'Search and add products',
                prefixIcon: Icon(Icons.search_rounded))),
        const SizedBox(height: 12),
        _categoryFilters(),
        const SizedBox(height: 16),
        Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _productGrid(_products, provider, wide))
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
    if (products.isEmpty) {
      return const Center(
          child: Text('No products found. Try another category or search.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6C7486))));
    }
    return GridView.builder(
      controller: _productsController,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: wide ? 260 : 190,
          childAspectRatio: wide ? .98 : .76,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12),
      itemCount: products.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (_, index) {
        if (index == products.length) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF365FF4)));
        }
        final product = products[index];
        final stock = product['stockQuantity'] as int? ?? 0;
        final inCart = provider.cartItems.containsKey(product['id']);
        final imageUrl = product['imageUrl'] as String? ?? '';
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
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F3F8),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: imageUrl.isEmpty
                                  ? const Icon(Icons.inventory_2_outlined,
                                      color: Color(0xFFA1A8B7), size: 34)
                                  : Image.network(imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.inventory_2_outlined,
                                          color: Color(0xFFA1A8B7),
                                          size: 34)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(product['categoryName'] ?? 'PRODUCT',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF365FF4),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(product['name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF172033),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                          const SizedBox(height: 7),
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

  Widget _categoryFilters() => SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final category = index == 0 ? null : _categories[index - 1];
            final id = category?['id'] as int?;
            final selected = _selectedCategoryId == id;
            return FilterChip(
              selected: selected,
              showCheckmark: false,
              label: Text(category?['name'] ?? 'All products',
                  overflow: TextOverflow.ellipsis),
              onSelected: (_) => _selectCategory(id),
              selectedColor: const Color(0xFFEEF0FF),
              labelStyle: TextStyle(
                  color: selected
                      ? const Color(0xFF365FF4)
                      : const Color(0xFF172033),
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
              side: BorderSide(
                  color: selected
                      ? const Color(0xFF365FF4)
                      : const Color(0xFFE6E8EF)),
              backgroundColor: Colors.white,
            );
          },
        ),
      );

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
