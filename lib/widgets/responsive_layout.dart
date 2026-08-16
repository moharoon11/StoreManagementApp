import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../views/billing/pos_checkout_view.dart';
import '../views/categories/categories_view.dart';
import '../views/dashboard/dashboard_view.dart';
import '../views/invoices/invoice_history_view.dart';
import '../views/products/products_view.dart';
import '../views/reports/sales_reports_view.dart';
import '../views/stock/stock_management_view.dart';
import '../views/store/store_profile_view.dart';

class ResponsiveLayout extends StatefulWidget {
  const ResponsiveLayout({super.key});
  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  static const _views = <Widget>[
    DashboardView(),
    PosCheckoutView(),
    ProductsView(),
    CategoriesView(),
    InvoiceHistoryView(),
    StockManagementView(),
    SalesReportsView(),
    StoreProfileView()
  ];
  static const _items = <_Destination>[
    _Destination('Home', 'Your daily command centre', Icons.home_outlined,
        Icons.home_rounded),
    _Destination('Sell', 'Create a new sale', Icons.point_of_sale_outlined,
        Icons.point_of_sale_rounded),
    _Destination('Products', 'Browse and manage items',
        Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    _Destination('Categories', 'Organise your catalogue',
        Icons.account_tree_outlined, Icons.account_tree_rounded),
    _Destination('Invoices', 'Sales history and documents',
        Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    _Destination('Stock', 'Inventory movement', Icons.warehouse_outlined,
        Icons.warehouse_rounded),
    _Destination('Insights', 'Business performance', Icons.auto_graph_outlined,
        Icons.auto_graph_rounded),
    _Destination('Business', 'Your company profile', Icons.storefront_outlined,
        Icons.storefront_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final active = _items[provider.selectedNavIndex];
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Column(children: [
        SafeArea(
            bottom: false,
            child: _TopBar(
                title: active.title,
                subtitle: active.subtitle,
                onBusiness: () => provider.setNavIndex(7))),
        Expanded(
            child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                child: KeyedSubtree(
                    key: ValueKey(provider.selectedNavIndex),
                    child: _views[provider.selectedNavIndex]))),
      ]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: width >= 760 ? 76 : 70,
          selectedIndex: _bottomIndex(provider.selectedNavIndex),
          indicatorColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: .14),
          onDestinationSelected: (index) {
            if (index == 4) {
              _showMore(context);
            } else {
              provider.setNavIndex([0, 1, 2, 6][index]);
            }
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale_rounded),
                label: 'Sell'),
            NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: 'Products'),
            NavigationDestination(
                icon: Icon(Icons.auto_graph_outlined),
                selectedIcon: Icon(Icons.auto_graph_rounded),
                label: 'Insights'),
            NavigationDestination(
                icon: Icon(Icons.apps_rounded), label: 'More'),
          ],
        ),
      ),
    );
  }

  int _bottomIndex(int index) =>
      switch (index) { 0 => 0, 1 => 1, 2 => 2, 6 => 3, _ => 4 };

  void _showMore(BuildContext context) {
    final provider = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('More tools',
                    style: TextStyle(
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
                const SizedBox(height: 5),
                Text('Everything else for your business.',
                    style: TextStyle(
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .65),
                        fontSize: 12)),
                const SizedBox(height: 16),
                GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    childAspectRatio: 2.75,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      for (final index in [3, 4, 5, 7])
                        _MoreTool(
                            item: _items[index],
                            onTap: () {
                              provider.setNavIndex(index);
                              Navigator.pop(sheetContext);
                            })
                    ]),
                const SizedBox(height: 18),
                Text('Appearance',
                    style: TextStyle(
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(height: 10),
                Row(children: [
                  for (final option in AppThemeOption.values) ...[
                    Expanded(
                        child: _ThemeChoice(
                            option: option,
                            selected: provider.themeOption == option,
                            onTap: () => provider.setThemeOption(option))),
                    if (option != AppThemeOption.values.last)
                      const SizedBox(width: 8),
                  ]
                ]),
                const SizedBox(height: 10),
                TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      provider.logout();
                    },
                    icon: const Icon(Icons.logout_rounded,
                        color: Color(0xFFE75C5C)),
                    label: const Text('Sign out',
                        style: TextStyle(
                            color: Color(0xFFE75C5C),
                            fontWeight: FontWeight.w800))),
              ]),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.title, required this.subtitle, required this.onBusiness});
  final String title, subtitle;
  final VoidCallback onBusiness;
  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant))),
        child: Row(children: [
          if (title != 'Home')
            IconButton(
                onPressed: () => context.read<AppProvider>().setNavIndex(0),
                tooltip: 'Back to Home',
                icon: Icon(Icons.arrow_back_rounded,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .65))),
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.auto_graph_rounded,
                  color: Colors.white, size: 20)),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
                Text(subtitle,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .62),
                        fontSize: 10))
              ])),
          IconButton(
              onPressed: onBusiness,
              tooltip: 'Business profile',
              icon: Icon(Icons.storefront_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .65))),
        ]),
      );
}

class _MoreTool extends StatelessWidget {
  const _MoreTool({required this.item, required this.onTap});
  final _Destination item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Icon(item.selectedIcon, color: scheme.primary, size: 19),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(item.title,
                        style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)))
              ]))),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice(
      {required this.option, required this.selected, required this.onTap});
  final AppThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, swatch) = switch (option) {
      AppThemeOption.light => ('Light', const Color(0xFF365FF4)),
      AppThemeOption.nightOwl => ('Night Owl', const Color(0xFF8B9CFF)),
      AppThemeOption.evergreen => ('Sand', const Color(0xFF9A4E25)),
    };
    return Material(
      color: selected ? scheme.primary.withValues(alpha: .12) : scheme.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 66,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 1.5 : 1),
              borderRadius: BorderRadius.circular(13)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 19,
                height: 19,
                decoration:
                    BoxDecoration(color: swatch, shape: BoxShape.circle)),
            const SizedBox(height: 5),
            Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 10,
                    fontWeight: FontWeight.w700))
          ]),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.title, this.subtitle, this.icon, this.selectedIcon);
  final String title, subtitle;
  final IconData icon, selectedIcon;
}
