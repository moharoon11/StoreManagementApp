import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';

class SalesReportsView extends StatefulWidget {
  const SalesReportsView({super.key});

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
      if (res['success'] == true && mounted) {
        setState(() {
          _reportData = res['data'];
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _reportData?['totalSales'] ?? 0;
    final totalInvoices = _reportData?['totalInvoices'] ?? 0;
    final totalProductsSold = _reportData?['totalProductsSold'] ?? 0;
    final topSoldProducts = (_reportData?['topSoldProducts'] as List?) ?? [];
    final salesByCategory = (_reportData?['salesByCategory'] as List?) ?? [];

    return WorkspacePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(
            eyebrow: 'Insights',
            title: 'Sales reports',
            description:
                'Review revenue, invoices, and product movement inside a tighter analytical layout.',
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['today', 'week', 'month'].map((period) {
                final selected = _selectedPeriod == period;
                return ChoiceChip(
                  label: Text(period.toUpperCase()),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (value) {
                    if (!value) return;
                    setState(() => _selectedPeriod = period);
                    _fetchReport();
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  AdaptiveWrapGrid(
                    minItemWidth: 190,
                    children: [
                      StatTile(
                        label: 'Revenue',
                        value: '₹$totalSales',
                        icon: Icons.payments_outlined,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      StatTile(
                        label: 'Invoices',
                        value: '$totalInvoices',
                        icon: Icons.receipt_long_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      StatTile(
                        label: 'Products sold',
                        value: '$totalProductsSold',
                        icon: Icons.shopping_bag_outlined,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AdaptiveWrapGrid(
                    minItemWidth: 300,
                    children: [
                      _ReportTable(
                        title: 'Top sold products',
                        subtitle: 'Best performing items for this period',
                        items: topSoldProducts,
                        emptyLabel: 'No product sales recorded for this period.',
                        builder: (context, item) => _ReportRow(
                          title: (item['productName'] ?? '').toString(),
                          subtitle:
                              '${formatQuantity(item['totalQuantitySold'])} ${item['unit'] ?? 'units'} sold',
                          trailing: '₹${item['totalRevenue']}',
                        ),
                      ),
                      _ReportTable(
                        title: 'Sales by category',
                        subtitle: 'How each category contributed',
                        items: salesByCategory,
                        emptyLabel: 'No category-level data recorded for this period.',
                        builder: (context, item) => _ReportRow(
                          title: (item['categoryName'] ?? '').toString(),
                          subtitle:
                              '${formatQuantity(item['totalQuantitySold'])} ${item['unit'] ?? 'units'} sold',
                          trailing: '₹${item['totalRevenue']}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.emptyLabel,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final List<dynamic> items;
  final String emptyLabel;
  final Widget Function(BuildContext context, dynamic item) builder;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: title,
      subtitle: subtitle,
      child: items.isEmpty
          ? Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  builder(context, items[i]),
                  if (i != items.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}
