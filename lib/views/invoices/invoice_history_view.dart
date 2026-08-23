import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';

class InvoiceHistoryView extends StatefulWidget {
  const InvoiceHistoryView({Key? key}) : super(key: key);

  @override
  State<InvoiceHistoryView> createState() => _InvoiceHistoryViewState();
}

class _InvoiceHistoryViewState extends State<InvoiceHistoryView> {
  bool _isLoading = true;
  List<dynamic> _invoices = [];
  Map<String, dynamic> _summary = {
    'totalTransactions': 0,
    'totalSale': 0.0,
    'balanceDue': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchInvoices(),
      _fetchSummary(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchInvoices() async {
    try {
      final res = await ApiService.get(ApiConfig.invoices, queryParameters: {'pageSize': '100'});
      if (res['success'] == true && mounted) {
        _invoices = res['data']['items'] ?? [];
      }
    } catch (_) {}
  }

  Future<void> _fetchSummary() async {
    try {
      final res = await ApiService.get('${ApiConfig.invoices}/summary');
      if (res['success'] == true && mounted) {
        _summary = res['data'] ?? _summary;
      }
    } catch (_) {}
  }

  Future<void> _downloadPdf(int invoiceId, String invoiceNum) async {
    try {
      final bytes = await InvoicePdfService.fetch(invoiceId);
      final wasSaved = await InvoicePdfService.save(bytes, 'Invoice_$invoiceNum.pdf');
      if (mounted && wasSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _openSaleEditModal(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SaleDetailModal(
        invoice: invoice,
        onUpdated: _loadData,
        onPdfRequested: () => _downloadPdf(invoice['id'], invoice['invoiceNumber'] ?? '1'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE), // Modern light blue background matching screenshot
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Sale Report',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2563EB)),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : Column(
              children: [
                // Top Date Filter Bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Text('This Month', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 13)),
                            SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down, color: Color(0xFF2563EB), size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.calendar_month_outlined, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${DateTime.now().year}-08-01 TO ${DateTime.now().year}-08-31',
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Metric summary cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _metricCard('No of Txns', '${_summary['totalTransactions'] ?? _invoices.length}'),
                      const SizedBox(width: 8),
                      _metricCard('Total Sale', '₹ ${((_summary['totalSale'] ?? 0.0) as num).toStringAsFixed(2)}'),
                      const SizedBox(width: 8),
                      _metricCard('Balance Due', '₹ ${((_summary['balanceDue'] ?? 0.0) as num).toStringAsFixed(2)}', isDue: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Invoices List
                Expanded(
                  child: _invoices.isEmpty
                      ? const Center(
                          child: Text('No sales records found.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            final inv = _invoices[index];
                            final custName = (inv['customerName'] ?? '').toString().trim();
                            final nameDisplay = custName.isEmpty || custName == 'NO_NAME' ? 'Walk-in Customer' : custName;
                            final totalAmt = (inv['grandTotal'] as num?)?.toDouble() ?? 0.0;
                            final balDue = (inv['balanceDue'] as num?)?.toDouble() ?? 0.0;
                            final dateStr = (inv['createdAt'] ?? '').toString();
                            final dateFormatted = dateStr.contains('T') ? dateStr.split('T').first : dateStr;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: InkWell(
                                onTap: () => _openSaleEditModal(inv),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            nameDisplay,
                                            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'SALE ${inv['id']}',
                                                style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                              Text(
                                                dateFormatted,
                                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Amount', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
                                              Text('₹ ${totalAmt.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Balance', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
                                              Text(
                                                '₹ ${balDue.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: balDue > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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

  Widget _metricCard(String label, String val, {bool isDue = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              val,
              style: TextStyle(
                color: isDue ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleDetailModal extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onUpdated;
  final VoidCallback onPdfRequested;

  const _SaleDetailModal({
    required this.invoice,
    required this.onUpdated,
    required this.onPdfRequested,
  });

  @override
  State<_SaleDetailModal> createState() => _SaleDetailModalState();
}

class _SaleDetailModalState extends State<_SaleDetailModal> {
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _amountReceivedController;
  late bool _isReceived;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final custName = (widget.invoice['customerName'] ?? '').toString();
    _nameController = TextEditingController(text: custName == 'NO_NAME' ? '' : custName);
    _mobileController = TextEditingController(text: (widget.invoice['customerMobileNumber'] ?? '').toString());

    final grandTotal = (widget.invoice['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final amtRec = (widget.invoice['amountReceived'] as num?)?.toDouble() ?? grandTotal;
    _isReceived = (widget.invoice['isReceived'] as bool?) ?? (amtRec >= grandTotal);
    _amountReceivedController = TextEditingController(text: amtRec.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _amountReceivedController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final grandTotal = (widget.invoice['grandTotal'] as num?)?.toDouble() ?? 0.0;
      final amtRec = double.tryParse(_amountReceivedController.text) ?? (_isReceived ? grandTotal : 0.0);

      final res = await ApiService.put('${ApiConfig.invoices}/${widget.invoice['id']}', {
        'customerName': _nameController.text.trim(),
        'customerMobileNumber': _mobileController.text.trim(),
        'isReceived': _isReceived,
        'amountReceived': amtRec,
      });

      if (res['success'] == true) {
        widget.onUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale updated successfully!'), backgroundColor: Color(0xFF10B981)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to update sale.'), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteInvoice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale'),
        content: const Text('Are you sure you want to delete this sale invoice?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final res = await ApiService.delete('${ApiConfig.invoices}/${widget.invoice['id']}');
      if (res['success'] == true) {
        widget.onUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale deleted.'), backgroundColor: Color(0xFF10B981)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = (widget.invoice['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final amtRec = double.tryParse(_amountReceivedController.text) ?? (_isReceived ? grandTotal : 0.0);
    final balanceDue = (grandTotal - amtRec).clamp(0.0, double.infinity);
    final items = (widget.invoice['items'] as List?) ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // AppBar / Header matching Screenshot 1
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('Sale', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFEF4444)),
                  onPressed: widget.onPdfRequested,
                  tooltip: 'PDF',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content Scroll
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Invoice No & Date row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Invoice No. ${widget.invoice['id']}', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('Date: ${(widget.invoice['createdAt'] ?? '').toString().split('T').first}', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Customer inputs card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Billed Items card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF60A5FA),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Billed Items', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        ...items.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final item = entry.value;
                          final price = (item['sellingPrice'] as num?)?.toDouble() ?? 0.0;
                          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                          final total = (item['total'] as num?)?.toDouble() ?? (price * qty);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                  child: Text('#$idx', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['productName'] ?? 'Item', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text('Item Subtotal: $qty × ₹$price = ₹$total', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text('₹ $total', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Totals card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('₹ ${grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Checkbox(
                              value: _isReceived,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                setState(() {
                                  _isReceived = val ?? true;
                                  if (_isReceived) {
                                    _amountReceivedController.text = grandTotal.toStringAsFixed(2);
                                  } else {
                                    _amountReceivedController.text = '0.00';
                                  }
                                });
                              },
                            ),
                            const Text('Received', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                            const Spacer(),
                            SizedBox(
                              width: 120,
                              height: 38,
                              child: TextField(
                                controller: _amountReceivedController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                                onChanged: (v) => setState(() {}),
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Balance Due', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              '₹ ${balanceDue.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: balanceDue > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
          // Bottom Actions matching Screenshot 1 (Delete & Edit)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _deleteInvoice,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0091FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
