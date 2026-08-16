import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text('Error: $_error', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFEF4444))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
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
    final lowStockProducts = (_dashboardData?['lowStockProducts'] as List?) ?? [];
    final mostSoldProducts = (_dashboardData?['mostSoldProducts'] as List?) ?? [];

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: const Color(0xFF2563EB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Store Overview',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Real-time overview of sales, stock & activity',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF2563EB)),
                  onPressed: _loadDashboard,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Metric Cards Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: screenWidth > 900 ? 4 : (screenWidth > 600 ? 2 : 1),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: screenWidth > 600 ? 2.3 : 3.0,
              children: [
                _buildMetricCard("Today's Sales", '₹${todaySales.toString()}', Icons.payments_outlined, const Color(0xFF10B981), const Color(0xFFECFDF5)),
                _buildMetricCard("Today's Invoices", todayInvoices.toString(), Icons.receipt_long_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                _buildMetricCard("Total Products", totalProducts.toString(), Icons.inventory_2_outlined, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
                _buildMetricCard("Total Categories", totalCategories.toString(), Icons.category_outlined, const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
              ],
            ),
            const SizedBox(height: 24),
            // Content Sections: Low Stock & Top Products stacked on mobile
            if (isMobile) ...[
              _buildSectionCard(
                'Low Stock Alerts',
                Icons.warning_amber_rounded,
                const Color(0xFFF59E0B),
                _buildLowStockContent(lowStockProducts),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                'Most Sold Items',
                Icons.star_outline_rounded,
                const Color(0xFF2563EB),
                _buildMostSoldContent(mostSoldProducts),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSectionCard(
                      'Low Stock Alerts',
                      Icons.warning_amber_rounded,
                      const Color(0xFFF59E0B),
                      _buildLowStockContent(lowStockProducts),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSectionCard(
                      'Most Sold Items',
                      Icons.star_outline_rounded,
                      const Color(0xFF2563EB),
                      _buildMostSoldContent(mostSoldProducts),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Color iconColor, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          child,
        ],
      ),
    );
  }

  Widget _buildLowStockContent(List lowStockProducts) {
    if (lowStockProducts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text('All products are sufficiently stocked.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      );
    }
    return Column(
      children: lowStockProducts.map((p) {
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFFFFBEB),
            child: const Icon(Icons.inventory_2, color: Color(0xFFF59E0B), size: 18),
          ),
          title: Text(p['name'] ?? '', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text('Price: ₹${p['sellingPrice']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${p['stockQuantity']} left',
              style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 11),
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
        child: Text('No sales records yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      );
    }
    return Column(
      children: mostSoldProducts.map((p) {
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFEFF6FF),
            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF2563EB), size: 18),
          ),
          title: Text(p['productName'] ?? '', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text('${p['totalQuantitySold']} units sold', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          trailing: Text(
            '₹${p['totalRevenue']}',
            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
          ),
        );
      }).toList(),
    );
  }
}
