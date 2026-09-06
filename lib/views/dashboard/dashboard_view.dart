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
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF365FF4)));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFFE75C5C)),
              const SizedBox(height: 12),
              Text('Error: $_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE75C5C))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF365FF4),
                    foregroundColor: Colors.white),
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

    final width = MediaQuery.sizeOf(context).width;
    final provider = context.watch<AppProvider>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return WorkspacePage(
      child: Stack(children: [
        Positioned(
          top: -120,
          right: -100,
          child: IgnorePointer(
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                  color: Color(0x142563EB), shape: BoxShape.circle),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -130,
          child: IgnorePointer(
            child: Container(
              width: 270,
              height: 270,
              decoration: const BoxDecoration(
                  color: Color(0x1212A594), shape: BoxShape.circle),
            ),
          ),
        ),
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: _loadDashboard,
            child: ListView(children: [
              _dashboardGreeting(greeting, provider.username),
              const SizedBox(height: 14),
              _salesHero(todaySales, todayInvoices, totalProducts),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _actionCard(
                    width: width,
                    title: 'New bill',
                    subtitle: 'Create a normal bill',
                    icon: Icons.add_rounded,
                    colors: const [Color(0xFF2563EB), Color(0xFF104FC7)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManualBillingView(),
                        ),
                      );
                    }),
                _actionCard(
                    width: width,
                    title: 'Quick bill',
                    subtitle: 'Fast billing in seconds',
                    icon: Icons.bolt_rounded,
                    colors: const [Color(0xFFFF9D00), Color(0xFFE66B00)],
                    onTap: () => provider.setNavIndex(1)),
              ]),
              const SizedBox(height: 16),
              if (salesTrend.isNotEmpty) ...[
                _salesTrendChart(salesTrend),
                const SizedBox(height: 16),
              ],
              _recentBills(recentInvoices, provider),
              const SizedBox(height: 16),
              if (width < 800) ...[
                _buildActivityPanel(
                    'Stock to review',
                    'Keep your shelves ready',
                    Icons.inventory_rounded,
                    const Color(0xFFE4A331),
                    _buildLowStockContent(lowStockProducts)),
                const SizedBox(height: 12),
                _buildActivityPanel(
                    'Customer favourites',
                    'What is selling best',
                    Icons.workspace_premium_outlined,
                    const Color(0xFF365FF4),
                    _buildMostSoldContent(mostSoldProducts))
              ] else
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: _buildActivityPanel(
                          'Stock to review',
                          'Keep your shelves ready',
                          Icons.inventory_rounded,
                          const Color(0xFFE4A331),
                          _buildLowStockContent(lowStockProducts))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildActivityPanel(
                          'Customer favourites',
                          'What is selling best',
                          Icons.workspace_premium_outlined,
                          const Color(0xFF365FF4),
                          _buildMostSoldContent(mostSoldProducts)))
                ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _dashboardGreeting(String greeting, String username) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('STORE MANAGEMENT',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: Ui.headingSize(context),
                  letterSpacing: -1,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('$greeting${username.isEmpty ? '' : ', $username'}',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .62),
                  fontSize: 13))
        ])),
        IconButton(
            onPressed: _loadDashboard,
            tooltip: 'Refresh dashboard',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.refresh_rounded,
                size: 21, color: Theme.of(context).colorScheme.primary))
      ]);

  Widget _salesHero(dynamic sales, dynamic invoices, dynamic products) =>
      Container(
          padding:
              EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 15 : 18),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A86F7), Color(0xFF1556C0)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x66FFFFFF)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x3D1556C0),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: Offset(0, 9))
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("TODAY'S SALES",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .85),
                      fontWeight: FontWeight.w800,
                      fontSize: 11)),
              const Spacer(),
              Icon(Icons.auto_graph_rounded,
                  size: 19, color: Colors.white.withValues(alpha: .7))
            ]),
            const SizedBox(height: 8),
            Text('₹$sales',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 13),
            Container(height: 1, color: Colors.white.withValues(alpha: .25)),
            const SizedBox(height: 12),
            Row(children: [
              _heroStat(
                  Icons.receipt_long_outlined, '$invoices', 'TOTAL BILLS'),
              Container(
                  height: 34,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white.withValues(alpha: .25)),
              _heroStat(Icons.inventory_2_outlined, '$products', 'PRODUCTS'),
            ])
          ]));

  Widget _heroStat(IconData icon, String value, String label) => Expanded(
          child: Row(children: [
        Container(
            padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(
                color: Color(0x22FFFFFF), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(width: 9),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xDFFFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800))
        ])
      ]));

  Widget _actionCard(
          {required double width,
          required String title,
          required String subtitle,
          required IconData icon,
          required List<Color> colors,
          required VoidCallback onTap}) =>
      SizedBox(
          width: width >= 680
              ? (width >= 760 ? width - 68 : width - 44) / 2
              : double.infinity,
          child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                      height: 82,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: colors.last.withValues(alpha: .27),
                                blurRadius: 14,
                                offset: const Offset(0, 6))
                          ]),
                      child: Row(children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: Icon(icon, color: colors.first, size: 21)),
                        const SizedBox(width: 11),
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xDFFFFFFF), fontSize: 11))
                            ])),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white, size: 24)
                      ])))));

  Widget _recentBills(List invoices, AppProvider provider) => Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x140F2454), blurRadius: 14, offset: Offset(0, 6))
          ]),
      child: SurfacePanel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 10, 10),
                child: Row(children: [
                  const Expanded(
                      child: Text('RECENT BILLS',
                          style: TextStyle(
                              color: Color(0xFF172033),
                              fontSize: 13,
                              fontWeight: FontWeight.w800))),
                  TextButton(
                      onPressed: () => provider.setNavIndex(4),
                      child: const Text('View all'))
                ])),
            const Divider(),
            if (invoices.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(22),
                  child: Text('Your completed bills will appear here.',
                      style: TextStyle(color: Color(0xFF6C7486))))
            else
              ...invoices.take(4).map((invoice) => ListTile(
                  onTap: () => provider.setNavIndex(4),
                  leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEEF4FF),
                      child: Icon(Icons.receipt_long_outlined,
                          color: Color(0xFF2563EB))),
                  title: Text(invoice['invoiceNumber'] ?? 'Invoice',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      '${invoice['createdAt'] ?? ''}'.replaceFirst('T', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                  trailing: Text('₹${invoice['grandTotal']}',
                      style: const TextStyle(
                          color: Color(0xFF16834B),
                          fontWeight: FontWeight.w800)))),
          ])));

  Widget _buildActivityPanel(String title, String subtitle, IconData icon,
          Color color, Widget content) =>
      Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x120F2454),
                    blurRadius: 12,
                    offset: Offset(0, 5))
              ]),
          child: SurfacePanel(
              padding: EdgeInsets.zero,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Row(children: [
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: color.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(9)),
                              child: Icon(icon, color: color, size: 17)),
                          const SizedBox(width: 10),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface)),
                                Text(subtitle,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: .6),
                                        fontSize: 11))
                              ])
                        ])),
                    const Divider(),
                    content
                  ])));

  Widget _buildLowStockContent(List lowStockProducts) {
    if (lowStockProducts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text('All products are sufficiently stocked.',
            style: TextStyle(color: Color(0xFF6C7486), fontSize: 13)),
      );
    }
    return Column(
      children: lowStockProducts.map((p) {
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFFFF8E8),
            child: const Icon(Icons.inventory_2,
                color: Color(0xFFE4A331), size: 18),
          ),
          title: Text(p['name'] ?? '',
              style: const TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          subtitle: Text('Price: ₹${p['sellingPrice']}',
              style: const TextStyle(color: Color(0xFF6C7486), fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${formatQuantity(p['stockQuantity'])} ${p['unit'] ?? 'Piece'} left',
              style: const TextStyle(
                  color: Color(0xFFE75C5C),
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMostSoldContent(List mostSoldProducts) {
    if (mostSoldProducts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text('No sales records yet.',
            style: TextStyle(color: Color(0xFF6C7486), fontSize: 13)),
      );
    }
    return Column(
      children: mostSoldProducts.map((p) {
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFEEF0FF),
            child: const Icon(Icons.shopping_bag_outlined,
                color: Color(0xFF365FF4), size: 18),
          ),
          title: Text(p['productName'] ?? '',
              style: const TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          subtitle: Text(
              '${formatQuantity(p['totalQuantitySold'])} ${p['unit'] ?? 'units'} sold',
              style: const TextStyle(color: Color(0xFF6C7486), fontSize: 12)),
          trailing: Text(
            '₹${p['totalRevenue']}',
            style: const TextStyle(
                color: Color(0xFF12A594),
                fontWeight: FontWeight.bold,
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

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 16, 22, 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x120F2454), blurRadius: 12, offset: Offset(0, 5))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFF365FF4).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.show_chart_rounded,
                    color: Color(0xFF365FF4), size: 17),
              ),
              const SizedBox(width: 10),
              const Text('7-Day Sales Trend',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Color(0xFF172033),
                  )),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFE5E7EB),
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
                              style: const TextStyle(
                                  color: Color(0xFF6C7486), fontSize: 10),
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
                          style: const TextStyle(
                              color: Color(0xFF6C7486), fontSize: 10),
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
                    color: const Color(0xFF365FF4),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF365FF4),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF365FF4).withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
