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
    final totalCategories = _dashboardData?['totalCategories'] ?? 0;
    final lowStockProducts =
        (_dashboardData?['lowStockProducts'] as List?) ?? [];
    final mostSoldProducts =
        (_dashboardData?['mostSoldProducts'] as List?) ?? [];

    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1120
        ? 4
        : width >= 650
            ? 2
            : 1;
    return WorkspacePage(
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(children: [
          PageIntro(
              eyebrow: 'Workspace home',
              title: 'Everything, in one place.',
              description: 'Choose a part of your business to work on.',
              action: OutlinedButton.icon(
                  onPressed: _loadDashboard,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'))),
          const SizedBox(height: 24),
          _buildLauncher(context, width),
          const SizedBox(height: 24),
          Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1D2B5C), Color(0xFF365FF4)]),
                  borderRadius: BorderRadius.circular(22)),
              child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 18,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Today's revenue",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(.72),
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 7),
                          Text('₹$todaySales',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  letterSpacing: -1.5,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('$todayInvoices invoices created today',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(.8),
                                  fontSize: 12))
                        ]),
                    Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.13),
                            borderRadius: BorderRadius.circular(17)),
                        child: const Icon(Icons.trending_up_rounded,
                            color: Color(0xFF82E9DE), size: 35))
                  ])),
          const SizedBox(height: 18),
          GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                // A fixed, generous height prevents the value and its helper
                // text from being pushed below the card on small phones.
                mainAxisExtent: columns == 1 ? 142 : 154,
              ),
              children: [
                StatTile(
                    label: 'Invoices today',
                    value: '$todayInvoices',
                    note: 'Transactions created',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFF365FF4)),
                StatTile(
                    label: 'Products',
                    value: '$totalProducts',
                    note: 'In your catalogue',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF8D63D8)),
                StatTile(
                    label: 'Categories',
                    value: '$totalCategories',
                    note: 'Ways customers browse',
                    icon: Icons.account_tree_outlined,
                    color: const Color(0xFFE4A331)),
                StatTile(
                    label: 'Stock alerts',
                    value: '${lowStockProducts.length}',
                    note: 'Items need a check',
                    icon: Icons.priority_high_rounded,
                    color: const Color(0xFFE75C5C))
              ]),
          const SizedBox(height: 24),
          if (width < 780) ...[
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
    );
  }

  Widget _buildActivityPanel(String title, String subtitle, IconData icon,
          Color color, Widget content) =>
      SurfacePanel(
          padding: EdgeInsets.zero,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ]));

  Widget _buildLauncher(BuildContext context, double width) {
    final provider = context.read<AppProvider>();
    const tools = [
      (1, 'New sale', Icons.point_of_sale_rounded, Color(0xFF12A594)),
      (2, 'Products', Icons.inventory_2_rounded, Color(0xFF365FF4)),
      (3, 'Categories', Icons.account_tree_rounded, Color(0xFF8D63D8)),
      (4, 'Invoices', Icons.receipt_long_rounded, Color(0xFFE4A331)),
      (5, 'Stock', Icons.warehouse_rounded, Color(0xFFE75C5C)),
      (6, 'Insights', Icons.auto_graph_rounded, Color(0xFF365FF4)),
      (7, 'Business', Icons.storefront_rounded, Color(0xFF12A594)),
    ];
    final crossAxisCount = width >= 1100
        ? 7
        : width >= 760
            ? 4
            : 3;
    return SurfacePanel(
      padding: const EdgeInsets.all(14),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        childAspectRatio: width < 500 ? .95 : 1.25,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: [
          for (final tool in tools)
            _launcherItem(
                tool.$2, tool.$3, tool.$4, () => provider.setNavIndex(tool.$1))
        ],
      ),
    );
  }

  Widget _launcherItem(
          String label, IconData icon, Color color, VoidCallback onTap) =>
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 21)),
            const SizedBox(height: 7),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ]),
        ),
      );

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
