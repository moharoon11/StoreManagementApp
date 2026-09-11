import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/workspace_ui.dart';
import '../billing/manual_billing_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiService.get(ApiConfig.dashboard);
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _dashboardData = res['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = (res['message'] ?? 'Unable to load dashboard.').toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return WorkspacePage(
        child: EmptyCanvas(
          icon: Icons.cloud_off_rounded,
          title: 'Dashboard unavailable',
          detail: _error!,
        ),
      );
    }

    final provider = context.watch<AppProvider>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final todaySales = _dashboardData?['todaySales'] ?? 0;
    final todayInvoices = _dashboardData?['todayInvoiceCount'] ?? 0;
    final totalProducts = _dashboardData?['totalProducts'] ?? 0;
    final lowStockProducts =
        (_dashboardData?['lowStockProducts'] as List<dynamic>? ?? []);
    final mostSoldProducts =
        (_dashboardData?['mostSoldProducts'] as List<dynamic>? ?? []);
    final recentInvoices =
        (_dashboardData?['recentInvoices'] as List<dynamic>? ?? []);
    final salesTrend = (_dashboardData?['salesTrend'] as List<dynamic>? ?? []);

    return WorkspacePage(
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PageIntro(
              eyebrow: 'Overview',
              title:
                  '$greeting${provider.username.isEmpty ? '' : ', ${provider.username}'}',
              description:
                  'Start selling, check stock pressure, and keep the store moving from one calmer workspace.',
              action: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManualBillingView(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('New manual bill'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => provider.setNavIndex(1),
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('Quick sale'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _HeroCard(
              sales: todaySales,
              invoices: todayInvoices,
              products: totalProducts,
            ),
            const SizedBox(height: 16),
            AdaptiveWrapGrid(
              minItemWidth: 200,
              children: [
                StatTile(
                  label: 'Today sales',
                  value: '₹$todaySales',
                  icon: Icons.payments_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  note: '$todayInvoices invoices processed today',
                ),
                StatTile(
                  label: 'Products',
                  value: '$totalProducts',
                  icon: Icons.inventory_2_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                  note: 'Live across your store catalogue',
                ),
                StatTile(
                  label: 'Low stock',
                  value: '${lowStockProducts.length}',
                  icon: Icons.notification_important_outlined,
                  color: Theme.of(context).colorScheme.error,
                  note: lowStockProducts.isEmpty
                      ? 'No urgent restocking alerts'
                      : 'Items to review before the day ends',
                ),
                StatTile(
                  label: 'Top sellers',
                  value: '${mostSoldProducts.length}',
                  icon: Icons.workspace_premium_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                  note: 'Products with the strongest movement',
                ),
              ],
            ),
            if (salesTrend.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SalesTrendPanel(salesTrend: salesTrend),
            ],
            const SizedBox(height: 16),
            AdaptiveWrapGrid(
              minItemWidth: 280,
              children: [
                _InvoicePanel(
                  invoices: recentInvoices,
                  onViewAll: () => provider.setNavIndex(4),
                ),
                _InventoryPanel(
                  title: 'Stock watch',
                  subtitle: 'Products nearing the limit',
                  icon: Icons.inventory_2_outlined,
                  items: lowStockProducts,
                  emptyLabel: 'Everything looks comfortably stocked.',
                  accent: Theme.of(context).colorScheme.tertiary,
                  rowBuilder: (context, item) => _SimpleMetricRow(
                    title: (item['name'] ?? 'Product').toString(),
                    subtitle:
                        '₹${item['sellingPrice']} · ${item['stockQuantity']} ${item['unit'] ?? 'Piece'} left',
                    trailing: 'Review',
                    trailingColor: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                _InventoryPanel(
                  title: 'Customer favourites',
                  subtitle: 'What is moving fastest today',
                  icon: Icons.auto_awesome_outlined,
                  items: mostSoldProducts,
                  emptyLabel:
                      'Sales activity will appear here once billing starts.',
                  accent: Theme.of(context).colorScheme.secondary,
                  rowBuilder: (context, item) => _SimpleMetricRow(
                    title: (item['productName'] ?? 'Product').toString(),
                    subtitle:
                        '${item['totalQuantitySold']} ${item['unit'] ?? 'units'} sold',
                    trailing: '₹${item['totalRevenue']}',
                    trailingColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.sales,
    required this.invoices,
    required this.products,
  });

  final dynamic sales;
  final dynamic invoices;
  final dynamic products;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return SurfacePanel(
      padding: EdgeInsets.all(wide ? 24 : 20),
      child: wide
          ? Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _HeroCopy(
                    sales: sales,
                    invoices: invoices,
                    products: products,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: _HeroLedger(
                    sales: sales,
                    invoices: invoices,
                    products: products,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCopy(
                  sales: sales,
                  invoices: invoices,
                  products: products,
                ),
                const SizedBox(height: 20),
                _HeroLedger(
                  sales: sales,
                  invoices: invoices,
                  products: products,
                ),
              ],
            ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.sales,
    required this.invoices,
    required this.products,
  });

  final dynamic sales;
  final dynamic invoices;
  final dynamic products;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusPill(
          label: 'Operations snapshot',
          color: scheme.primary,
        ),
        const SizedBox(height: 10),
        Text(
          'Move between billing, stock, and reporting without losing context.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 30,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Today’s sales, urgent stock pressure, and the catalogue footprint are grouped into one denser panel so the workspace feels calm on mobile and clear on desktop.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface.withValues(alpha: .7),
              ),
        ),
      ],
    );
  }
}

class _HeroLedger extends StatelessWidget {
  const _HeroLedger({
    required this.sales,
    required this.invoices,
    required this.products,
  });

  final dynamic sales;
  final dynamic invoices;
  final dynamic products;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroStat(
            label: 'Today sales',
            value: '₹$sales',
            color: scheme.primary,
          ),
          const SizedBox(height: 14),
          _HeroStat(
            label: 'Bills completed',
            value: '$invoices',
            color: scheme.secondary,
          ),
          const SizedBox(height: 14),
          _HeroStat(
            label: 'Products live',
            value: '$products',
            color: scheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.circle,
            size: 12,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: .6),
                      letterSpacing: 1.4,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SalesTrendPanel extends StatelessWidget {
  const _SalesTrendPanel({required this.salesTrend});

  final List<dynamic> salesTrend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spots = <FlSpot>[];
    double maxY = 0;

    for (var i = 0; i < salesTrend.length; i++) {
      final y = (salesTrend[i]['totalSales'] as num?)?.toDouble() ?? 0;
      if (y > maxY) maxY = y;
      spots.add(FlSpot(i.toDouble(), y));
    }

    if (maxY == 0) maxY = 100;
    maxY *= 1.18;

    return SectionPanel(
      title: 'Sales rhythm',
      subtitle: 'A cleaner view of the recent billing trend.',
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (salesTrend.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                color: scheme.outlineVariant,
                strokeWidth: 1,
                dashArray: const [6, 6],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: maxY / 4,
                  getTitlesWidget: (value, _) => Text(
                    value >= 1000
                        ? '${(value / 1000).toStringAsFixed(1)}k'
                        : value.toInt().toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index < 0 || index >= salesTrend.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        (salesTrend[index]['dateLabel'] ?? '').toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: scheme.primary,
                barWidth: 3,
                belowBarData: BarAreaData(
                  show: true,
                  color: scheme.primary.withValues(alpha: .12),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 4,
                    color: scheme.surface,
                    strokeWidth: 2,
                    strokeColor: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoicePanel extends StatelessWidget {
  const _InvoicePanel({
    required this.invoices,
    required this.onViewAll,
  });

  final List<dynamic> invoices;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Recent invoices',
      subtitle: 'Jump back into your latest sales and documents.',
      action: TextButton(
        onPressed: onViewAll,
        child: const Text('View all'),
      ),
      child: invoices.isEmpty
          ? const Text(
              'Completed invoices will appear here once billing starts.')
          : Column(
              children: [
                for (final invoice in invoices.take(4)) ...[
                  _SimpleMetricRow(
                    title: (invoice['invoiceNumber'] ?? 'Invoice').toString(),
                    subtitle: '${invoice['createdAt'] ?? ''}'
                        .toString()
                        .replaceFirst('T', ' '),
                    trailing: '₹${invoice['grandTotal']}',
                    trailingColor: Theme.of(context).colorScheme.primary,
                  ),
                  if (invoice != invoices.take(4).last)
                    const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.emptyLabel,
    required this.accent,
    required this.rowBuilder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<dynamic> items;
  final String emptyLabel;
  final Color accent;
  final Widget Function(BuildContext context, dynamic item) rowBuilder;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: title,
      subtitle: subtitle,
      action: StatusPill(
        label: '${items.length}',
        color: accent,
      ),
      child: items.isEmpty
          ? Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: [
                for (final item in items.take(4)) ...[
                  rowBuilder(context, item),
                  if (item != items.take(4).last) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _SimpleMetricRow extends StatelessWidget {
  const _SimpleMetricRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .24),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: .62),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: trailingColor,
                ),
          ),
        ],
      ),
    );
  }
}
