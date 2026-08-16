import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

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
      final res = await ApiService.get(ApiConfig.invoices, queryParameters: {'pageSize': '50'});
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

  Future<void> _openPdf(int invoiceId) async {
    final pdfUrl = '${ApiConfig.baseUrl}/invoices/$invoiceId/pdf';
    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: 'Invoice_$invoiceId.pdf',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load PDF. Status: ${response.statusCode}'), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading PDF: ${e.toString()}'), backgroundColor: const Color(0xFFEF4444)),
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
              Text('Invoice ${invoice['invoiceNumber']}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444)),
                onPressed: () => _openPdf(invoice['id']),
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
                    Text('Grand Total: ₹${invoice['grandTotal']}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Text('${invoice['createdAt']?.toString().split('T').first}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 4),
              ...items.map((item) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['productName'] ?? '', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                  subtitle: Text('Qty: ${item['quantity']} × ₹${item['sellingPrice']}', style: const TextStyle(color: Color(0xFF64748B))),
                  trailing: Text('₹${item['total']}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _openPdf(invoice['id']),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Download / Share PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invoice History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
          const SizedBox(height: 20),
          Expanded(
            child: _invoices.isEmpty
                ? const Center(child: Text('No invoices generated yet.', style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final inv = _invoices[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: const Icon(Icons.receipt_long, color: Color(0xFF2563EB), size: 20),
                          ),
                          title: Text(inv['invoiceNumber'] ?? '', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('Date: ${inv['createdAt']?.toString().replaceAll('T', ' ').substring(0, 16)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₹${inv['grandTotal']}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444), size: 20),
                                onPressed: () => _openPdf(inv['id']),
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
