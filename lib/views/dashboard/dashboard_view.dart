import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/ui_breakpoints.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/app_provider.dart';
import '../billing/manual_billing_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

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
      if (res['success'] == true) {
        setState(() {
          _dashboardData = res['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: scheme.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.error_outline,
                    size: 40, color: scheme.error),
              ),
              const SizedBox(height: 12),
              Text('Error: $_error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final todaySales = _dashboardData?['todaySales'] ?? 0;
    final todayInvoices = _dashboardData?['todayInvoiceCount'] ?? 0;
    final totalProducts = _dashboardData?['totalProducts'] ?? 0;
    final lowStockProducts =
        (_dashboardData?['lowStockProducts'] as List?) ?? [];
    final mostSoldProducts =
        (_dashboardData?['mostSoldProducts'] as List?) ?? [];
    final recentInvoices = (_dashboardData?['recentInvoices'] as List?) ?? [];
    final salesTrend = (_dashboardData?['salesTrend'] as List?) ?? [];

    final provider = context.watch<AppProvider>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return WorkspacePage(
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(children: [
          _dashboardGreeting(greeting, provider.username),
          const SizedBox(height: 12),
          _salesHero(todaySales, todayInvoices, totalProducts),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final twoUp = constraints.maxWidth >= 560;
            Widget billCard = _LedgerAction(
                title: 'New bill',
                subtitle: 'Create a normal bill',
                icon: Icons.receipt_long_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManualBillingView(),
                    ),
                  );
                });
            Widget quickCard = _LedgerAction(
                title: 'Quick bill',
                subtitle: 'Fast billing in seconds',
                icon: Icons.bolt_outlined,
                onTap: () => provider.setNavIndex(1));
            if (twoUp) {
              return Row(children: [
                Expanded(child: billCard),
                const SizedBox(width: 10),
                Expanded(child: quickCard),
              ]);
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  billCard,
                  const SizedBox(height: 10),
                  quickCard,
                ]);
          }),
          const SizedBox(height: 16),
          if (salesTrend.isNotEmpty) ...[
            _salesTrendChart(salesTrend),
            const SizedBox(height: 16),
          ],
          _recentBills(recentInvoices, provider),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final twoUp = constraints.maxWidth >= 800;
            final stock = _buildActivityPanel(
                'Stock to review',
                'Keep your shelves ready',
                Icons.inventory_2_outlined,
                Theme.of(context).colorScheme.secondary,
                _buildLowStockContent(lowStockProducts));
            final favs = _buildActivityPanel(
                'Customer favourites',
                'What is selling best',
                Icons.workspace_premium_outlined,
                Theme.of(context).colorScheme.primary,
                _buildMostSoldContent(mostSoldProducts));
            if (twoUp) {
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: stock),
                    const SizedBox(width: 12),
                    Expanded(child: favs),
                  ]);
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  stock,
                  const SizedBox(height: 12),
                  favs,
                ]);
          }),
        ]),
      ),
    );
  }

  Widget _dashboardGreeting(String greeting, String username) =>
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(2),
            )),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DAY BOOK',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .55),
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('$greeting${username.isEmpty ? '' : ', $username'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: Ui.headingSize(context),
                  fontWeight: FontWeight.w700))
        ])),
        OutlinedButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh')),
      ]);

  Widget _salesHero(dynamic sales, dynamic invoices, dynamic products) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 15 : 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text("TODAY'S TAKINGS",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: .55),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      fontSize: 11)),
            ),
            LedgerTag(
                label: '$invoices bills',
                color: scheme.primary,
                icon: Icons.receipt_long_outlined),
          ]),
          const SizedBox(height: 8),
          Text('₹$sales',
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 30,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 12),
          Divider(color: scheme.outlineVariant, height: 1),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final row = constraints.maxWidth >= 420;
            final bills = _heroStat(Icons.receipt_long_outlined,
                '$invoices', 'BILLS', scheme.primary);
            final goods = _heroStat(Icons.inventory_2_outlined,
                '$products', 'GOODS', scheme.secondary);
            if (row) {
              return Row(children: [
                bills,
                Container(
                    height: 34,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: scheme.outlineVariant),
                goods,
              ]);
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  bills,
                  const SizedBox(height: 10),
                  goods,
                ]);
          }),
        ]));
  }

  Widget _heroStat(IconData icon, String value, String label, Color color) =>
      Expanded(
          child: Row(children: [
        LedgerStamp(icon: icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .55),
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ]))
              ]),
        )
      ]));

  /// Ruled two-line action row — replaces the old gradient action cards.
  // ignore: non_constant_identifier_names
  Widget _LedgerAction(
          {required String title,
          required String subtitle,
          required IconData icon,
          required VoidCallback onTap}) =>
      SurfacePanel(
          accent: false,
          padding: const EdgeInsets.all(12),
          child: Material(
              color: Colors.transparent,
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(children: [
                    LedgerStamp(
                        icon: icon,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 11),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: .55),
                                  fontSize: 11))
                        ])),
                    Icon(Icons.east_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .4),
                        size: 20)
                  ]))));

  Widget _recentBills(List invoices, AppProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
        accent: false,
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 10, 10),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('RECENT BILLS',
                          style: TextStyle(
                              color: scheme.onSurface
                                  .withValues(alpha: .55),
                              fontSize: 11,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Latest completed bills',
                          style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ])),
                TextButton(
                    onPressed: () => provider.setNavIndex(4),
                    child: const Text('View all'))
              ])),
          Divider(color: scheme.outlineVariant, height: 1),
          if (invoices.isEmpty)
            Padding(
                padding: const EdgeInsets.all(22),
                child: Text('Your completed bills will appear here.',
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .55))))
          else
            ...invoices.take(4).map((invoice) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                        onTap: () => provider.setNavIndex(4),
                        leading: LedgerStamp(
                            icon: Icons.receipt_long_outlined,
                            color: scheme.primary),
                        title: Text(
                            invoice['invoiceNumber'] ?? 'Invoice',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${invoice['createdAt'] ?? ''}'
                                .replaceFirst('T', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)),
                        trailing: Text('₹${invoice['grandTotal']}',
                            style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800))),
                    Divider(
                        color: scheme.outlineVariant, height: 1),
                  ],
                )),
        ]));
  }


  Widget _buildActivityPanel(String title, String subtitle, IconData icon,
          Color color, Widget content) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
        accent: false,
        padding: EdgeInsets.zero,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(children: [
                    LedgerStamp(icon: icon, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: scheme.onSurface)),
                            Text(subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: scheme.onSurface
                                        .withValues(alpha: .55),
                                    fontSize: 11))
                          ]),
                    )
                  ])),
              Divider(color: scheme.outlineVariant, height: 1),
              content
            ]));
  }


  Widget _buildLowStockContent(List lowStockProducts) {
    final scheme = Theme.of(context).colorScheme;
    if (lowStockProducts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text('All products are sufficiently stocked.',
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .55),
                fontSize: 13)),
      );
    }
    return Column(
      children: lowStockProducts.map((p) {
        return ListTile(
          dense: true,
          leading: LedgerStamp(
              icon: Icons.inventory_2_outlined, color: scheme.secondary),
          title: Text(p['name'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          subtitle: Text('Price: ₹${p['sellingPrice']}',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .55),
                  fontSize: 12)),
          trailing: LedgerTag(
            label:
                '${formatQuantity(p['stockQuantity'])} ${p['unit'] ?? 'Piece'} left',
            color: scheme.error,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMostSoldContent(List mostSoldProducts) {
    final scheme = Theme.of(context).colorScheme;
    if (mostSoldProducts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text('No sales records yet.',
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .55),
                fontSize: 13)),
      );
    }
    return Column(
      children: mostSoldProducts.map((p) {
        return ListTile(
          dense: true,
          leading: LedgerStamp(
              icon: Icons.shopping_basket_outlined,
              color: scheme.primary),
          title: Text(p['productName'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          subtitle: Text(
              '${formatQuantity(p['totalQuantitySold'])} ${p['unit'] ?? 'units'} sold',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .55),
                  fontSize: 12)),
          trailing: Text(
            '₹${p['totalRevenue']}',
            style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13),
          ),
        );
      }).toList(),
    );
  }

  Widget _salesTrendChart(List salesTrend) {
    if (salesTrend.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    double maxY = 0;

    for (int i = 0; i < salesTrend.length; i++) {
      double y = (salesTrend[i]['totalSales'] ?? 0).toDouble();
      if (y > maxY) maxY = y;
      spots.add(FlSpot(i.toDouble(), y));
    }

    if (maxY == 0) maxY = 100;
    maxY = maxY * 1.2;

    final scheme = Theme.of(context).colorScheme;
    final lineColor = scheme.primary;
    final gridColor = scheme.outlineVariant;
    return SurfacePanel(
      accent: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
      child: SizedBox(
        height: 224,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LedgerStamp(
                    icon: Icons.show_chart_outlined, color: lineColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('7-DAY TREND',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                              fontSize: 11,
                              color: scheme.onSurface
                                  .withValues(alpha: .55),
                            )),
                        Text('Takings by day',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: scheme.onSurface,
                            )),
                      ]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < salesTrend.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              salesTrend[index]['dateLabel'] ?? '',
                              style: TextStyle(
                                  color: scheme.onSurface
                                      .withValues(alpha: .55),
                                  fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY > 0 ? maxY / 4 : 1,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toInt().toString(),
                          style: TextStyle(
                              color: scheme.onSurface
                                  .withValues(alpha: .55),
                              fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (salesTrend.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: scheme.surface,
                        strokeWidth: 2,
                        strokeColor: lineColor,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
