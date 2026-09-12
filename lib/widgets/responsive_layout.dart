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
import 'cart_checkout.dart';
import 'ui_breakpoints.dart';
import '../utils/quantity_utils.dart';

/// All navigation destinations, shared by the bottom bar, index sheet and
/// the desktop ledger rail.
const _navItems = <_Destination>[
  _Destination('Home', 'Day book at a glance', Icons.home_outlined,
      Icons.home_rounded),
  _Destination('Sell', 'Record a new sale', Icons.point_of_sale_outlined,
      Icons.point_of_sale_rounded),
  _Destination('Products', 'Goods and price lists',
      Icons.inventory_2_outlined, Icons.inventory_2_rounded),
  _Destination('Categories', 'Shelves and sections',
      Icons.account_tree_outlined, Icons.account_tree_rounded),
  _Destination('Invoices', 'Bills and receipts',
      Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  _Destination('Stock', 'Goods movement', Icons.warehouse_outlined,
      Icons.warehouse_rounded),
  _Destination('Insights', 'Trade performance', Icons.auto_graph_outlined,
      Icons.auto_graph_rounded),
  _Destination('Business', 'Firm profile', Icons.storefront_outlined,
      Icons.storefront_rounded),
];

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final active = _navItems[provider.selectedNavIndex];
    final width = MediaQuery.sizeOf(context).width;
    final expanded = width >= Ui.mediumMax;

    final content = Column(children: [
      SafeArea(
          bottom: false,
          child: _LedgerHeader(
              title: active.title,
              subtitle: active.subtitle,
              onBusiness: () => provider.setNavIndex(7))),
      Expanded(
          child: Center(
        // Constrained box keeps ledgers readable and centred on wide windows.
        child: SizedBox(
          width: width.clamp(0.0, Ui.maxContentWidth),
          child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              child: KeyedSubtree(
                  key: ValueKey(provider.selectedNavIndex),
                  child: _views[provider.selectedNavIndex])),
        ),
      )),
    ]);

    if (expanded) {
      return Scaffold(
        body: Row(children: [
          _LedgerRail(
              selectedIndex: provider.selectedNavIndex,
              onSelect: provider.setNavIndex),
          Expanded(child: content),
        ]),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
                top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: NavigationBar(
            height: 68,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _bottomIndex(provider.selectedNavIndex),
            onDestinationSelected: (index) {
              if (index == 4) {
                _showIndex(context);
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
                icon: Icon(Icons.grid_view_outlined), label: 'Index'),
          ],
          ),
        ),
      ),
    );
  }

  int _bottomIndex(int index) =>
      switch (index) { 0 => 0, 1 => 1, 2 => 2, 6 => 3, _ => 4 };

  void _showIndex(BuildContext context) {
    final provider = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .72,
          minChildSize: .5,
          maxChildSize: .92,
          builder: (_, controller) => _IndexSheetBody(
              controller: controller, provider: provider),
        ),
      ),
    );
  }
}

/// Tall labelled rail for tablets and desktop: dark forest spine with
/// brass selection rules and the firm wordmark on top.
class _LedgerRail extends StatelessWidget {
  const _LedgerRail({required this.selectedIndex, required this.onSelect});
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final dark = scheme.brightness == Brightness.dark;
    final spine = dark ? scheme.surface : const Color(0xFF10281E);
    final onSpine = dark ? scheme.onSurface : Colors.white;
    return Container(
      width: 216,
      decoration: BoxDecoration(
          color: spine,
          border: Border(right: BorderSide(color: scheme.outlineVariant))),
      child: SafeArea(
        right: false,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: scheme.secondary,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.account_balance_outlined,
                      color: dark ? scheme.onSurface : const Color(0xFF10281E),
                      size: 19)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NEXORA',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: onSpine,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.4,
                              fontSize: 13)),
                      Text('trade ledger',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: onSpine.withValues(alpha: .6),
                              fontSize: 10,
                              letterSpacing: 1.2)),
                    ]),
              ),
            ]),
          ),
          Divider(color: onSpine.withValues(alpha: .14), height: 1),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('SECTIONS',
                style: TextStyle(
                    color: onSpine.withValues(alpha: .5),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontSize: 10)),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) => _RailRow(
                  item: _navItems[index],
                  selected: index == selectedIndex,
                  onSpine: onSpine,
                  onTap: () => onSelect(index)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(
                      color: onSpine.withValues(alpha: .14), height: 1),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                    for (final option in AppThemeOption.values) ...[
                      _RailThemeDot(
                          option: option,
                          selected: provider.themeOption == option,
                          onTap: () => provider.setThemeOption(option)),
                      if (option != AppThemeOption.values.last)
                        const SizedBox(width: 8),
                    ]
                  ]),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        foregroundColor:
                            onSpine.withValues(alpha: .75)),
                    onPressed: provider.logout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                  ),
                ]),
          ),
        ]),
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  const _RailRow(
      {required this.item,
      required this.selected,
      required this.onSpine,
      required this.onTap});
  final _Destination item;
  final bool selected;
  final Color onSpine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: selected
            ? onSpine.withValues(alpha: .1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: selected
            ? Border(left: BorderSide(color: scheme.secondary, width: 3))
            : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(children: [
              Icon(selected ? item.selectedIcon : item.icon,
                  size: 19,
                  color: selected
                      ? scheme.secondary
                      : onSpine.withValues(alpha: .6)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: selected
                                  ? onSpine
                                  : onSpine.withValues(alpha: .75),
                              fontWeight: FontWeight.w700)),
                      Text(item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              color: onSpine.withValues(alpha: .45))),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RailThemeDot extends StatelessWidget {
  const _RailThemeDot(
      {required this.option, required this.selected, required this.onTap});
  final AppThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final swatch = switch (option) {
      AppThemeOption.light => const Color(0xFF134E3A),
      AppThemeOption.nightOwl => const Color(0xFF7BC9A3),
      AppThemeOption.evergreen => const Color(0xFF5B3B0A),
    };
    return InkWell(
      onTap: onTap,
      customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4)),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
            color: swatch,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: selected ? scheme.secondary : scheme.outlineVariant,
                width: selected ? 2 : 1)),
      ),
    );
  }
}

class _LedgerHeader extends StatelessWidget {
  const _LedgerHeader(
      {required this.title, required this.subtitle, required this.onBusiness});
  final String title, subtitle;
  final VoidCallback onBusiness;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < Ui.compactMax;
    final cartCount =
        context.select<AppProvider, double>((provider) => provider.cartCount);
    return Container(
      padding: EdgeInsets.fromLTRB(
          compact ? 12 : 18, 10, compact ? 8 : 14, 10),
      decoration: BoxDecoration(
          color: scheme.surface,
          border:
              Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: Row(children: [
        if (title != 'Home')
          IconButton(
              onPressed: () => context.read<AppProvider>().setNavIndex(0),
              tooltip: 'Back to Home',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.west_rounded,
                  size: 20, color: scheme.onSurface.withValues(alpha: .65))),
        Container(
          width: 1,
          height: 30,
          margin: const EdgeInsets.only(right: 12),
          color: scheme.secondary,
        ),
        Expanded(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      fontSize: compact ? 13.5 : 15)),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: .55),
                      fontSize: 11))
            ])),
        IconButton(
          onPressed: () => openCart(context),
          tooltip: 'Current sale',
          visualDensity: VisualDensity.compact,
          icon: Badge(
            isLabelVisible: cartCount > 0,
            label: Text(formatQuantity(cartCount)),
            backgroundColor: scheme.primary,
            textColor: scheme.onPrimary,
            child: Icon(Icons.shopping_bag_outlined,
                size: 20, color: scheme.onSurface.withValues(alpha: .7)),
          ),
        ),
        IconButton(
            onPressed: onBusiness,
            tooltip: 'Business profile',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.business_outlined,
                size: 20, color: scheme.onSurface.withValues(alpha: .65))),
      ]),
    );
  }
}

/// Scrollable ledger-index sheet body (extracted so the bottom sheet can be
/// draggable + scrollable without nesting scrollables).
class _IndexSheetBody extends StatelessWidget {
  const _IndexSheetBody({required this.controller, required this.provider});
  final ScrollController controller;
  final AppProvider provider;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(controller: controller, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 26,
                height: 3,
                margin: const EdgeInsets.only(bottom: 5, right: 8),
                decoration: BoxDecoration(
                  color: scheme.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text('LEDGER INDEX',
                    style: TextStyle(
                        color:
                            scheme.onSurface.withValues(alpha: .55),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('All sections',
              style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 19)),
          const SizedBox(height: 4),
          Text('Every part of the firm, listed like an index.',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .6),
                  fontSize: 12)),
          const SizedBox(height: 10),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 6),
          for (final index in [3, 4, 5, 7])
            _IndexRow(
                item: _navItems[index],
                selected: provider.selectedNavIndex == index,
                onTap: () {
                  provider.setNavIndex(index);
                  Navigator.pop(context);
                }),
          const SizedBox(height: 10),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 10),
          Text('APPEARANCE',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .55),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  fontSize: 11)),
          const SizedBox(height: 10),
          _ThemeChoices(provider: provider),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                provider.logout();
              },
              icon: Icon(Icons.logout_rounded,
                  color: scheme.error, size: 18),
              label: Text('Sign out',
                  style: TextStyle(
                      color: scheme.error, fontWeight: FontWeight.w700))),
        ]),
      ),
    ]);
  }
}

/// Theme options that wrap instead of overflowing on narrow sheets.
class _ThemeChoices extends StatelessWidget {
  const _ThemeChoices({required this.provider});
  final AppProvider provider;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 420;
          if (narrow) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final option in AppThemeOption.values) ...[
                    _ThemeChoice(
                        option: option,
                        selected: provider.themeOption == option,
                        onTap: () =>
                            provider.setThemeOption(option)),
                    if (option != AppThemeOption.values.last)
                      const SizedBox(height: 8),
                  ]
                ]);
          }
          return Row(children: [
            for (final option in AppThemeOption.values) ...[
              Expanded(
                  child: _ThemeChoice(
                      option: option,
                      selected: provider.themeOption == option,
                      onTap: () =>
                          provider.setThemeOption(option))),
              if (option != AppThemeOption.values.last)
                const SizedBox(width: 8),
            ]
          ]);
        },
      );
}

class _IndexRow extends StatelessWidget {
  const _IndexRow(
      {required this.item, required this.selected, required this.onTap});
  final _Destination item;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color:
            selected ? scheme.primary.withValues(alpha: .07) : scheme.surface,
        border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(6)),
          child:
              Icon(item.selectedIcon, color: scheme.primary, size: 19),
        ),
        title: Text(item.title,
            style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        subtitle: Text(item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .55),
                fontSize: 11)),
        trailing: Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.chevron_right_rounded,
            color: selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: .35),
            size: 20),
      ),
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
      AppThemeOption.light => ('Forest', const Color(0xFF134E3A)),
      AppThemeOption.nightOwl => ('Night Ledger', const Color(0xFF1D2635)),
      AppThemeOption.evergreen => ('Parchment', const Color(0xFF5B3B0A)),
    };
    return Material(
      color: selected ? scheme.primary.withValues(alpha: .1) : scheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 1.5 : 1),
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
            Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                    color: swatch,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 16, color: scheme.primary),
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
