import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/ui_breakpoints.dart';

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

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: Ui.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Sales Reports',
                    style: TextStyle(
                        fontSize: Ui.headingSize(context),
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
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
                              fontSize: 11, fontWeight: FontWeight.w700)),
                      selected: isSelected,
                      selectedColor: scheme.primary,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurface.withValues(alpha: .6)),
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
          const SizedBox(height: 14),
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
                          const SizedBox(width: 10),
                          Expanded(
                              child: _buildReportMetric(
                                  'Total Invoices',
                                  '$totalInvoices',
                                  Icons.receipt_long,
                                  const Color(0xFF365FF4),
                                  const Color(0xFFEEF0FF))),
                          const SizedBox(width: 10),
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
                    const SizedBox(height: 16),
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
                       const SizedBox(height: 12),
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
                           const SizedBox(width: 12),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: .8),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .55),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(
      String title, List<dynamic> items, Widget Function(dynamic) itemBuilder) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
            child: Text(title,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800)),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(13),
                  child: Text('No data recorded for this period.',
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: .55),
                          fontSize: 12)))
              : Column(
                  children: items.map((item) => itemBuilder(item)).toList()),
        ],
      ),
    );
  }
}
