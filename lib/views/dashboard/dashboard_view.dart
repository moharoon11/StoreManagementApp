import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/workspace_ui.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

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
              const SizedBox(height: 20),
              _salesHero(todaySales, todayInvoices, totalProducts),
              const SizedBox(height: 18),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _actionCard(
                    width: width,
                    title: 'New bill',
                    subtitle: 'Create a normal bill',
                    icon: Icons.add_rounded,
                    colors: const [Color(0xFF2563EB), Color(0xFF104FC7)],
                    onTap: () => provider.setNavIndex(1)),
                _actionCard(
                    width: width,
                    title: 'Quick bill',
                    subtitle: 'Fast billing in seconds',
                    icon: Icons.bolt_rounded,
                    colors: const [Color(0xFFFF9D00), Color(0xFFE66B00)],
                    onTap: () => provider.setNavIndex(1)),
              ]),
              const SizedBox(height: 22),
              _recentBills(recentInvoices, provider),
              const SizedBox(height: 24),
              if (width < 800) ...[
                _buildActivityPanel(
                    'Stock to review',
                    'Keep your shelves ready',
                    Icons.inventory_rounded,
                    const Color(0xFFE4A331),
                    _buildLowStockContent(lowStockProducts)),
                const SizedBox(height: 16),
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
                  const SizedBox(width: 16),
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
          const Text('STORE MANAGEMENT',
              style: TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 25,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('$greeting${username.isEmpty ? '' : ', $username'}',
              style: const TextStyle(color: Color(0xFF6C7486), fontSize: 14))
        ])),
        IconButton(
            onPressed: _loadDashboard,
            tooltip: 'Refresh dashboard',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF365FF4)))
      ]);

  Widget _salesHero(dynamic sales, dynamic invoices, dynamic products) =>
      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A86F7), Color(0xFF1556C0)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x66FFFFFF)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x3D1556C0),
                    blurRadius: 26,
                    spreadRadius: 1,
                    offset: Offset(0, 12))
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("TODAY'S SALES",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .85),
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              const Spacer(),
              Icon(Icons.auto_graph_rounded,
                  color: Colors.white.withValues(alpha: .7))
            ]),
            const SizedBox(height: 12),
            Text('₹$sales',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    letterSpacing: -1.5,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Container(height: 1, color: Colors.white.withValues(alpha: .25)),
            const SizedBox(height: 16),
            Row(children: [
              _heroStat(
                  Icons.receipt_long_outlined, '$invoices', 'TOTAL BILLS'),
              Container(
                  height: 38,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 22),
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
                  fontSize: 21,
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
              borderRadius: BorderRadius.circular(19),
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(19),
                  child: Ink(
                      height: 110,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                          borderRadius: BorderRadius.circular(19),
                          boxShadow: [
                            BoxShadow(
                                color: colors.last.withValues(alpha: .27),
                                blurRadius: 18,
                                offset: const Offset(0, 8))
                          ]),
                      child: Row(children: [
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: Icon(icon, color: colors.first, size: 25)),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(subtitle,
                                  style: const TextStyle(
                                      color: Color(0xDFFFFFFF), fontSize: 12))
                            ])),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white, size: 28)
                      ])))));

  Widget _recentBills(List invoices, AppProvider provider) => Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x140F2454), blurRadius: 18, offset: Offset(0, 8))
          ]),
      child: SurfacePanel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                child: Row(children: [
                  const Expanded(
                      child: Text('RECENT BILLS',
                          style: TextStyle(
                              color: Color(0xFF172033),
                              fontSize: 15,
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
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x120F2454),
                    blurRadius: 16,
                    offset: Offset(0, 7))
              ]),
          child: SurfacePanel(
              padding: EdgeInsets.zero,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(children: [
                          Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                  color: color.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Icon(icon, color: color, size: 18)),
                          const SizedBox(width: 11),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF172033))),
                                Text(subtitle,
                                    style: const TextStyle(
                                        color: Color(0xFF6C7486), fontSize: 11))
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
              '${p['stockQuantity']} left',
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
          subtitle: Text('${p['totalQuantitySold']} units sold',
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
}
