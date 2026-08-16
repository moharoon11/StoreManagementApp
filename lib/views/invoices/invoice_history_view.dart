import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../services/invoice_pdf_service.dart';

class InvoiceHistoryView extends StatefulWidget {
  const InvoiceHistoryView({Key? key}) : super(key: key);

  @override
  State<InvoiceHistoryView> createState() => _InvoiceHistoryViewState();
}

class _InvoiceHistoryViewState extends State<InvoiceHistoryView> {
  bool _isLoading = true;
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(ApiConfig.invoices,
          queryParameters: {'pageSize': '50'});
      if (res['success'] == true) {
        setState(() {
          _invoices = res['data']['items'] ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdf(int invoiceId) async {
    try {
      final bytes = await InvoicePdfService.fetch(invoiceId);
      final wasSaved =
          await InvoicePdfService.save(bytes, 'Invoice_$invoiceId.pdf');
      if (mounted && wasSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error downloading PDF: ${e.toString()}'),
              backgroundColor: const Color(0xFFE75C5C)),
        );
      }
    }
  }

  void _showInvoiceDetail(Map<String, dynamic> invoice) {
    final items = (invoice['items'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Invoice ${invoice['invoiceNumber']}',
                  style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              IconButton(
                icon:
                    const Icon(Icons.picture_as_pdf, color: Color(0xFFE75C5C)),
                onPressed: () => _downloadPdf(invoice['id']),
                tooltip: 'Download PDF Invoice',
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand Total: ₹${invoice['grandTotal']}',
                        style: const TextStyle(
                            color: Color(0xFF12A594),
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Text('${invoice['createdAt']?.toString().split('T').first}',
                        style: const TextStyle(
                            color: Color(0xFF6C7486), fontSize: 12)),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFE6E8EF)),
              const SizedBox(height: 4),
              ...items.map((item) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['productName'] ?? '',
                      style: const TextStyle(
                          color: Color(0xFF172033),
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Qty: ${item['quantity']} × ₹${item['sellingPrice']}',
                      style: const TextStyle(color: Color(0xFF6C7486))),
                  trailing: Text('₹${item['total']}',
                      style: const TextStyle(
                          color: Color(0xFF12A594),
                          fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _downloadPdf(invoice['id']),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Download PDF'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE75C5C),
                foregroundColor: Colors.white),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF6C7486))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF365FF4)));
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invoice History',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172033),
                  letterSpacing: -0.5)),
          const SizedBox(height: 20),
          Expanded(
            child: _invoices.isEmpty
                ? const Center(
                    child: Text('No invoices generated yet.',
                        style: TextStyle(color: Color(0xFF6C7486))))
                : ListView.builder(
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final inv = _invoices[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE6E8EF)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          onTap: () => _showInvoiceDetail(inv),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEEF0FF),
                            child: const Icon(Icons.receipt_long,
                                color: Color(0xFF365FF4), size: 20),
                          ),
                          title: Text(inv['invoiceNumber'] ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF172033),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          subtitle: Text(
                              'Date: ${inv['createdAt']?.toString().replaceAll('T', ' ').substring(0, 16)}',
                              style: const TextStyle(
                                  color: Color(0xFF6C7486), fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₹${inv['grandTotal']}',
                                  style: const TextStyle(
                                      color: Color(0xFF12A594),
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf,
                                    color: Color(0xFFE75C5C), size: 20),
                                onPressed: () => _downloadPdf(inv['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
