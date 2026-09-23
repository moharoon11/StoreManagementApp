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
    final compact = MediaQuery.sizeOf(context).width < 760;

    return WorkspacePage(
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (!compact) ...[
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
            ],
            if (compact) ...[
              _MobileSalesPulse(
                sales: todaySales,
                invoices: todayInvoices,
                products: totalProducts,
                salesTrend: salesTrend,
              ),
              const SizedBox(height: 12),
              _MobileBillingActions(
                onManualBill: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManualBillingView(),
                    ),
                  );
                },
                onQuickSale: () => provider.setNavIndex(1),
              ),
              const SizedBox(height: 12),
            ] else ...[
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
            ],
            if (!compact && salesTrend.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SalesTrendPanel(salesTrend: salesTrend),
            ],
            const SizedBox(height: 16),
            AdaptiveWrapGrid(
              minItemWidth: compact ? 240 : 280,
              compactMinItemWidth: 220,
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

class _MobileSalesPulse extends StatelessWidget {
  const _MobileSalesPulse({
    required this.sales,
    required this.invoices,
    required this.products,
    required this.salesTrend,
  });

  final dynamic sales;
  final dynamic invoices;
  final dynamic products;
  final List<dynamic> salesTrend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.secondary, .72)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S SALES",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: .78),
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹$sales',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          _MobileSalesChart(salesTrend: salesTrend),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: .24)),
          const SizedBox(height: 10),
          Row(
            children: [
              _PulseMetric(
                icon: Icons.receipt_long_outlined,
                label: 'TOTAL BILLS',
                value: '$invoices',
              ),
              Container(
                width: 1,
                height: 38,
                color: Colors.white.withValues(alpha: .28),
              ),
              _PulseMetric(
                icon: Icons.inventory_2_outlined,
                label: 'PRODUCTS',
                value: '$products',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact version of the existing seven-day chart, placed inside the
/// mobile Today’s Sales card so it feels like one sales snapshot.
class _MobileSalesChart extends StatelessWidget {
  const _MobileSalesChart({required this.salesTrend});

  final List<dynamic> salesTrend;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    double maxY = 0;
    for (var index = 0; index < salesTrend.length; index++) {
      final value = (salesTrend[index]['totalSales'] as num?)?.toDouble() ?? 0;
      maxY = value > maxY ? value : maxY;
      spots.add(FlSpot(index.toDouble(), value));
    }

    if (spots.isEmpty) {
      return Container(
        height: 104,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Sales activity will appear here',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: .72),
              ),
        ),
      );
    }

    return SizedBox(
      height: 112,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: 0,
          maxY: maxY == 0 ? 100 : maxY * 1.18,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY == 0 ? 25 : maxY / 3,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: .16),
              strokeWidth: 1,
            ),
          ),
          titlesData: const FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.white,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: Colors.white.withValues(alpha: .13),
              ),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseMetric extends StatelessWidget {
  const _PulseMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: .9), size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: .72),
                        letterSpacing: .7,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _MobileBillingActions extends StatelessWidget {
  const _MobileBillingActions({
    required this.onManualBill,
    required this.onQuickSale,
  });

  final VoidCallback onManualBill;
  final VoidCallback onQuickSale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _BillingActionTile(
          icon: Icons.add_rounded,
          title: 'New bill',
          subtitle: 'Create a normal bill',
          color: scheme.primary,
          onTap: onQuickSale,
        ),
        const SizedBox(height: 10),
        _BillingActionTile(
          icon: Icons.bolt_rounded,
          title: 'Quick sale',
          subtitle: 'Fast billing in seconds',
          color: scheme.secondary,
          onTap: onManualBill,
        )

      
      ],
    );
  }
}

class _BillingActionTile extends StatelessWidget {
  const _BillingActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                  )),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: .78),
                                  )),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      );
}

// Kept for the wider dashboard layout variant.
// ignore: unused_element
class _QuickFocusStrip extends StatelessWidget {
  const _QuickFocusStrip({required this.lowStock, required this.favourites});

  final int lowStock;
  final int favourites;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _FocusTile(
            icon: Icons.inventory_2_outlined,
            label: 'Stock watch',
            value: '$lowStock to review',
            color: lowStock > 0 ? scheme.error : scheme.tertiary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FocusTile(
            icon: Icons.auto_awesome_outlined,
            label: 'Top movers',
            value: '$favourites active',
            color: scheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _FocusTile extends StatelessWidget {
  const _FocusTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
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
      title: '7-Day sales trend',
      subtitle: 'Your recent billing activity.',
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
      title: 'Recent bills',
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
