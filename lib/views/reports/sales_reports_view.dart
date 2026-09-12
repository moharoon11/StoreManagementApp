import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';

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
      if (res['success'] == true && mounted) {
        setState(() {
          _reportData = res['data'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalSales = _reportData?['totalSales'] ?? 0;
    final totalInvoices = _reportData?['totalInvoices'] ?? 0;
    final totalProductsSold = _reportData?['totalProductsSold'] ?? 0;
    final topSold = (_reportData?['topSoldProducts'] as List?) ?? [];
    final byCategory = (_reportData?['salesByCategory'] as List?) ?? [];

    return WorkspacePage(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageIntro(
          eyebrow: 'Sales overview',
          title: 'Reports',
          description:
              'A quick read on revenue, invoices and volume for the selected window.',
          action: Wrap(spacing: 6, runSpacing: 6, children: [
            _periodChip('today'),
            _periodChip('week'),
            _periodChip('month'),
          ]),
        ),
        const SizedBox(height: 14),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final metrics = [
                _metric('Total revenue', '₹$totalSales',
                    Icons.payments_rounded, scheme.primary),
                _metric('Invoices raised', '$totalInvoices',
                    Icons.receipt_long_rounded, scheme.secondary),
                _metric('Products sold', '$totalProductsSold',
                    Icons.inventory_2_rounded, scheme.tertiary),
              ];
              final metricRow = wide
                  ? Row(children: [
                      for (var i = 0; i < metrics.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: metrics[i]),
                      ],
                    ])
                  : Column(children: [
                      for (var i = 0; i < metrics.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        metrics[i],
                      ],
                    ]);

              final productsPanel = _tablePanel(
                'Top sold products',
                topSold,
                (p) => _soldRow(
                  name: p['productName'] ?? '',
                  detail:
                      '${formatQuantity(p['totalQuantitySold'])} ${p['unit'] ?? 'units'} sold',
                  value: '₹${p['totalRevenue']}',
                  valueColor: scheme.primary,
                ),
              );
              final categoriesPanel = _tablePanel(
                'Sales by category',
                byCategory,
                (c) => _soldRow(
                  name: c['categoryName'] ?? '',
                  detail: '${c['totalQuantitySold'] ?? 0} units sold',
                  value: '₹${c['totalRevenue']}',
                  valueColor: scheme.secondary,
                ),
              );

              return SingleChildScrollView(
                child: Column(children: [
                  metricRow,
                  const SizedBox(height: 14),
                  if (topSold.isEmpty && byCategory.isEmpty)
                    const EmptyCanvas(
                      icon: Icons.bar_chart_rounded,
                      title: 'No sales recorded',
                      detail: 'Sales figures for this window will appear here '
                          'once transactions are completed.',
                    )
                  else
                    wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(child: productsPanel),
                                const SizedBox(width: 12),
                                Expanded(child: categoriesPanel),
                              ])
                        : Column(children: [
                            productsPanel,
                            const SizedBox(height: 12),
                            categoriesPanel,
                          ]),
                ]),
              );
            }),
          ),
      ]),
    );
  }

  Widget _periodChip(String period) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedPeriod == period;
    return InkWell(
      onTap: () {
        if (selected) return;
        setState(() => _selectedPeriod = period);
        _fetchReport();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          border:
              Border.all(color: selected ? scheme.primary : scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          period.toUpperCase(),
          style: TextStyle(
            color: selected
                ? scheme.onPrimary
                : scheme.onSurface.withValues(alpha: .7),
            fontSize: 11,
            letterSpacing: .6,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) =>
      StatTile(label: label, value: value, icon: icon, color: color);

  Widget _soldRow(
      {required String name,
      required String detail,
      required String value,
      required Color valueColor}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text(detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .55),
                    fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 10),
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _tablePanel(
      String title, List<dynamic> items, Widget Function(dynamic) row) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      accent: true,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
          child: Row(children: [
            Text(title,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${items.length}',
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .4),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('No data recorded for this period.',
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .5),
                    fontSize: 12)),
          )
        else
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            row(items[i]),
          ],
      ]),
    );
  }
}