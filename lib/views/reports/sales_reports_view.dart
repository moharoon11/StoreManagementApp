import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class SalesReportsView extends StatefulWidget {
  const SalesReportsView({Key? key}) : super(key: key);

  @override
  State<SalesReportsView> createState() => _SalesReportsViewState();
}

class _SalesReportsViewState extends State<SalesReportsView> {
  bool _isLoading = true;
  String _selectedPeriod = 'today';
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(
        ApiConfig.salesReports,
        queryParameters: {'period': _selectedPeriod},
      );
      if (res['success'] == true) {
        setState(() {
          _reportData = res['data'];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _reportData?['totalSales'] ?? 0;
    final totalInvoices = _reportData?['totalInvoices'] ?? 0;
    final totalProductsSold = _reportData?['totalProductsSold'] ?? 0;
    final topSoldProducts = (_reportData?['topSoldProducts'] as List?) ?? [];
    final salesByCategory = (_reportData?['salesByCategory'] as List?) ?? [];

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Sales Reports',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172033),
                        letterSpacing: -0.5),
                    overflow: TextOverflow.ellipsis),
              ),
              Row(
                children: ['today', 'week', 'month'].map((period) {
                  final isSelected = _selectedPeriod == period;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: ChoiceChip(
                      label: Text(period.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF365FF4),
                      labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF6C7486)),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPeriod = period);
                          _fetchReport();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF365FF4))))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (isMobile) ...[
                      _buildReportMetric(
                          'Total Revenue',
                          '₹$totalSales',
                          Icons.payments,
                          const Color(0xFF12A594),
                          const Color(0xFFEAF9F6)),
                      const SizedBox(height: 12),
                      _buildReportMetric(
                          'Total Invoices',
                          '$totalInvoices',
                          Icons.receipt_long,
                          const Color(0xFF365FF4),
                          const Color(0xFFEEF0FF)),
                      const SizedBox(height: 12),
                      _buildReportMetric(
                          'Products Sold',
                          '$totalProductsSold',
                          Icons.shopping_bag,
                          const Color(0xFF8D63D8),
                          const Color(0xFFF4F0FF)),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                              child: _buildReportMetric(
                                  'Total Revenue',
                                  '₹$totalSales',
                                  Icons.payments,
                                  const Color(0xFF12A594),
                                  const Color(0xFFEAF9F6))),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildReportMetric(
                                  'Total Invoices',
                                  '$totalInvoices',
                                  Icons.receipt_long,
                                  const Color(0xFF365FF4),
                                  const Color(0xFFEEF0FF))),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildReportMetric(
                                  'Products Sold',
                                  '$totalProductsSold',
                                  Icons.shopping_bag,
                                  const Color(0xFF8D63D8),
                                  const Color(0xFFF4F0FF))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (isMobile) ...[
                      _buildTableCard('Top Sold Products', topSoldProducts,
                          (p) {
                        return ListTile(
                          dense: true,
                          title: Text(p['productName'] ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF172033),
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('${p['totalQuantitySold']} units sold',
                              style: const TextStyle(color: Color(0xFF6C7486))),
                          trailing: Text('₹${p['totalRevenue']}',
                              style: const TextStyle(
                                  color: Color(0xFF12A594),
                                  fontWeight: FontWeight.bold)),
                        );
                      }),
                      const SizedBox(height: 16),
                      _buildTableCard('Sales by Category', salesByCategory,
                          (c) {
                        return ListTile(
                          dense: true,
                          title: Text(c['categoryName'] ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF172033),
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('${c['totalQuantitySold']} units sold',
                              style: const TextStyle(color: Color(0xFF6C7486))),
                          trailing: Text('₹${c['totalRevenue']}',
                              style: const TextStyle(
                                  color: Color(0xFF365FF4),
                                  fontWeight: FontWeight.bold)),
                        );
                      }),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTableCard(
                                'Top Sold Products', topSoldProducts, (p) {
                              return ListTile(
                                dense: true,
                                title: Text(p['productName'] ?? '',
                                    style: const TextStyle(
                                        color: Color(0xFF172033),
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${p['totalQuantitySold']} units sold',
                                    style: const TextStyle(
                                        color: Color(0xFF6C7486))),
                                trailing: Text('₹${p['totalRevenue']}',
                                    style: const TextStyle(
                                        color: Color(0xFF12A594),
                                        fontWeight: FontWeight.bold)),
                              );
                            }),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTableCard(
                                'Sales by Category', salesByCategory, (c) {
                              return ListTile(
                                dense: true,
                                title: Text(c['categoryName'] ?? '',
                                    style: const TextStyle(
                                        color: Color(0xFF172033),
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${c['totalQuantitySold']} units sold',
                                    style: const TextStyle(
                                        color: Color(0xFF6C7486))),
                                trailing: Text('₹${c['totalRevenue']}',
                                    style: const TextStyle(
                                        color: Color(0xFF365FF4),
                                        fontWeight: FontWeight.bold)),
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportMetric(
      String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF6C7486),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(
      String title, List<dynamic> items, Widget Function(dynamic) itemBuilder) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EF)),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(title,
                style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1, color: Color(0xFFE6E8EF)),
          items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No data recorded for this period.',
                      style: TextStyle(color: Color(0xFF6C7486), fontSize: 13)))
              : Column(
                  children: items.map((item) => itemBuilder(item)).toList()),
        ],
      ),
    );
  }
}
