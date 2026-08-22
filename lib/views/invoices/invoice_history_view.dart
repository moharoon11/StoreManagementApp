import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../services/invoice_pdf_service.dart';
import '../../widgets/ui_breakpoints.dart';

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

    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Invoice ${invoice['invoiceNumber']}',
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.picture_as_pdf, color: scheme.error),
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
                        style: TextStyle(
                            color: scheme.secondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 12),
                    Text('${invoice['createdAt']?.toString().split('T').first}',
                        style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: .55),
                            fontSize: 12)),
                  ],
                ),
              ),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 4),
              ...items.map((item) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['productName'] ?? '',
                      style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Qty: ${item['quantity']} × ₹${item['sellingPrice']}',
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: .55))),
                  trailing: Text('₹${item['total']}',
                      style: TextStyle(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w800)),
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
                backgroundColor: scheme.error,
                foregroundColor: Colors.white),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: TextStyle(color: scheme.onSurface.withValues(alpha: .6))),
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

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: Ui.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invoice History',
              style: TextStyle(
                  fontSize: Ui.headingSize(context),
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Expanded(
            child: _invoices.isEmpty
                ? Center(
                    child: Text('No invoices generated yet.',
                        style:
                            TextStyle(color: scheme.onSurface.withValues(alpha: .6))))
                : ListView.builder(
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final inv = _invoices[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: ListTile(
                          onTap: () => _showInvoiceDetail(inv),
                          leading: CircleAvatar(
                            backgroundColor:
                                scheme.primary.withValues(alpha: .1),
                            radius: 17,
                            child: Icon(Icons.receipt_long,
                                color: scheme.primary, size: 18),
                          ),
                          title: Text(inv['invoiceNumber'] ?? '',
                              style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                          subtitle: Text(
                              'Date: ${inv['createdAt']?.toString().replaceAll('T', ' ').substring(0, 16)}',
                              style: TextStyle(
                                  color: scheme.onSurface.withValues(alpha: .55),
                                  fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₹${inv['grandTotal']}',
                                  style: TextStyle(
                                      color: scheme.secondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.picture_as_pdf,
                                    color: scheme.error, size: 19),
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
