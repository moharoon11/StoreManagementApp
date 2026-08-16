import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../views/dashboard/dashboard_view.dart';
import '../views/products/products_view.dart';
import '../views/billing/pos_checkout_view.dart';
import '../views/categories/categories_view.dart';
import '../views/invoices/invoice_history_view.dart';
import '../views/stock/stock_management_view.dart';
import '../views/reports/sales_reports_view.dart';
import '../views/store/store_profile_view.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({Key? key}) : super(key: key);

  final List<Widget> _views = const [
    DashboardView(),
    PosCheckoutView(),
    ProductsView(),
    CategoriesView(),
    InvoiceHistoryView(),
    StockManagementView(),
    SalesReportsView(),
    StoreProfileView(),
  ];

  static const List<_NavItemData> _navItems = [
    _NavItemData('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _NavItemData('POS Billing', Icons.point_of_sale_outlined, Icons.point_of_sale, isHighlight: true),
    _NavItemData('Products Catalog', Icons.inventory_2_outlined, Icons.inventory_2),
    _NavItemData('Categories', Icons.category_outlined, Icons.category),
    _NavItemData('Invoices History', Icons.receipt_long_outlined, Icons.receipt_long),
    _NavItemData('Stock Audit', Icons.inventory_outlined, Icons.inventory),
    _NavItemData('Sales Analytics', Icons.analytics_outlined, Icons.analytics),
    _NavItemData('Store Settings', Icons.store_outlined, Icons.store),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isWideDesktop = MediaQuery.of(context).size.width >= 1150;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Row(
          children: [
            // SaaS Desktop Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isWideDesktop ? 240 : 80,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A), // Deep Slate SaaS Theme
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(2, 0)),
                ],
              ),
              child: Column(
                children: [
                  // App Branding Header
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: isWideDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storefront, color: Colors.white, size: 22),
                        ),
                        if (isWideDesktop) ...[
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'StorePOS',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: -0.3),
                              ),
                              Text(
                                'SaaS Edition v1.0',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF1E293B), height: 1),
                  const SizedBox(height: 12),

                  // Navigation Links
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _navItems.length,
                      itemBuilder: (context, index) {
                        final item = _navItems[index];
                        final isSelected = provider.selectedNavIndex == index;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: InkWell(
                            onTap: () => provider.setNavIndex(index),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : (item.isHighlight ? const Color(0xFF1E293B) : Colors.transparent),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: isWideDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    color: isSelected ? Colors.white : (item.isHighlight ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                                    size: 20,
                                  ),
                                  if (isWideDesktop) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.isHighlight && !isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('POS', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Profile & Logout Box
                  const Divider(color: Color(0xFF1E293B), height: 1),
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: isWideDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF2563EB),
                          child: Text(
                            provider.username.isNotEmpty ? provider.username[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        if (isWideDesktop) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  provider.username,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Store Owner',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
                            onPressed: provider.logout,
                            tooltip: 'Logout',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area with Header
            Expanded(
              child: Column(
                children: [
                  // Top SaaS Header Bar
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _navItems[provider.selectedNavIndex].title,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                        ),
                        Row(
                          children: [
                            if (provider.selectedNavIndex != 1)
                              ElevatedButton.icon(
                                onPressed: () => provider.setNavIndex(1),
                                icon: const Icon(Icons.point_of_sale, size: 16),
                                label: const Text('Open POS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            const SizedBox(width: 14),
                            IconButton(
                              icon: const Icon(Icons.store, color: Color(0xFF64748B)),
                              onPressed: () => provider.setNavIndex(7),
                              tooltip: 'Store Settings',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Active View Body
                  Expanded(
                    child: _views[provider.selectedNavIndex],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Modern SaaS Mobile Layout
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _navItems[provider.selectedNavIndex].title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          actions: [
            if (provider.selectedNavIndex != 1)
              IconButton(
                icon: const Icon(Icons.point_of_sale, color: Color(0xFF10B981)),
                onPressed: () => provider.setNavIndex(1),
                tooltip: 'New Bill (POS)',
              ),
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
              onPressed: provider.logout,
              tooltip: 'Logout',
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: Colors.white,
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                ),
                accountName: Text(
                  provider.username,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                accountEmail: const Text('Store Owner SaaS Portal', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    provider.username.isNotEmpty ? provider.username[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _navItems.length,
                  itemBuilder: (context, index) {
                    final item = _navItems[index];
                    final isSelected = provider.selectedNavIndex == index;

                    return ListTile(
                      leading: Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: const Color(0xFFEFF6FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      onTap: () {
                        provider.setNavIndex(index);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                title: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                onTap: provider.logout,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        body: _views[provider.selectedNavIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: provider.selectedNavIndex > 3 ? 0 : provider.selectedNavIndex,
          onDestinationSelected: (int index) {
            if (index == 3) {
              // Open Drawer for all options if clicking "More"
              Scaffold.of(context).openDrawer();
            } else {
              provider.setNavIndex(index);
            }
          },
          backgroundColor: Colors.white,
          elevation: 8,
          indicatorColor: const Color(0xFFEFF6FF),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Color(0xFF2563EB)), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.point_of_sale_outlined, color: Color(0xFF10B981)), selectedIcon: Icon(Icons.point_of_sale, color: Color(0xFF10B981)), label: 'POS'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2, color: Color(0xFF2563EB)), label: 'Products'),
            NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
          ],
        ),
      );
    }
  }
}

class _NavItemData {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final bool isHighlight;

  const _NavItemData(this.title, this.icon, this.selectedIcon, {this.isHighlight = false});
}
