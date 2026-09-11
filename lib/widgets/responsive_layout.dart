import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/quantity_utils.dart';
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

const _navItems = <_Destination>[
  _Destination(
    title: 'Home',
    subtitle: 'Overview, activity, and quick actions',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _Destination(
    title: 'Sell',
    subtitle: 'Fast billing and checkout',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
  ),
  _Destination(
    title: 'Products',
    subtitle: 'Catalogue and item management',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
  ),
  _Destination(
    title: 'Categories',
    subtitle: 'Organise products by collection',
    icon: Icons.account_tree_outlined,
    selectedIcon: Icons.account_tree_rounded,
  ),
  _Destination(
    title: 'Invoices',
    subtitle: 'History, balance, and PDFs',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  _Destination(
    title: 'Stock',
    subtitle: 'Inventory movement and updates',
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse_rounded,
  ),
  _Destination(
    title: 'Insights',
    subtitle: 'Sales reports and performance',
    icon: Icons.auto_graph_outlined,
    selectedIcon: Icons.auto_graph_rounded,
  ),
  _Destination(
    title: 'Business',
    subtitle: 'Store profile and invoice identity',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront_rounded,
  ),
];

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key});

  static const _views = <Widget>[
    DashboardView(),
    PosCheckoutView(),
    ProductsView(),
    CategoriesView(),
    InvoiceHistoryView(),
    StockManagementView(),
    SalesReportsView(),
    StoreProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final expanded = width >= Ui.mediumMax;
    final scheme = Theme.of(context).colorScheme;
    final active = _navItems[provider.selectedNavIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Color.lerp(
                    Theme.of(context).scaffoldBackgroundColor,
                    scheme.primary,
                    .08,
                  ) ??
                  Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -160,
              right: -110,
              child: _Orb(
                size: 280,
                color: scheme.primary.withValues(alpha: .09),
              ),
            ),
            Positioned(
              bottom: -130,
              left: -80,
              child: _Orb(
                size: 220,
                color: scheme.secondary.withValues(alpha: .08),
              ),
            ),
            SafeArea(
              child: expanded
                  ? Row(
                      children: [
                        const SizedBox(width: 18),
                        _NavigationPanel(
                          selectedIndex: provider.selectedNavIndex,
                          onSelect: provider.setNavIndex,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _ContentShell(
                            active: active,
                            child: IndexedStack(
                              index: provider.selectedNavIndex,
                              children: _views,
                            ),
                            onQuickSale: () => provider.setNavIndex(1),
                            onOpenCart: () => openCart(context),
                            onOpenBusiness: () => provider.setNavIndex(7),
                          ),
                        ),
                        const SizedBox(width: 18),
                      ],
                    )
                  : Column(
                      children: [
                        _CompactHeader(
                          active: active,
                          onOpenCart: () => openCart(context),
                          onOpenBusiness: () => provider.setNavIndex(7),
                          onShowMore: () => _showMore(context),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                            child: _ContentShell(
                              active: active,
                              compact: true,
                              child: IndexedStack(
                                index: provider.selectedNavIndex,
                                children: _views,
                              ),
                              onQuickSale: () => provider.setNavIndex(1),
                              onOpenCart: () => openCart(context),
                              onOpenBusiness: () => provider.setNavIndex(7),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: expanded
          ? null
          : _BottomDock(
              selectedIndex: _bottomIndex(provider.selectedNavIndex),
              onSelect: (index) {
                if (index == 4) {
                  _showMore(context);
                  return;
                }
                provider.setNavIndex([0, 1, 2, 3][index]);
              },
            ),
    );
  }

  static int _bottomIndex(int index) =>
      switch (index) { 0 => 0, 1 => 1, 2 => 2, 3 => 3, _ => 4 };

  void _showMore(BuildContext context) {
    final provider = context.read<AppProvider>();
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace menu',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Switch tools, change mood, or sign out.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: .62),
                    ),
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.95,
                children: [
                  for (final index in [4, 5, 6, 7])
                    _MenuTile(
                      item: _navItems[index],
                      selected: provider.selectedNavIndex == index,
                      onTap: () {
                        provider.setNavIndex(index);
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final option in AppThemeOption.values) ...[
                    Expanded(
                      child: _ThemeChoice(
                        option: option,
                        selected: provider.themeOption == option,
                        onTap: () => provider.setThemeOption(option),
                      ),
                    ),
                    if (option != AppThemeOption.values.last)
                      const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    provider.logout();
                  },
                  icon: Icon(Icons.logout_rounded, color: scheme.error),
                  label: Text(
                    'Sign out',
                    style: TextStyle(color: scheme.error),
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

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final username = provider.username.trim();

    return SizedBox(
      width: 252,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: .08),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.auto_graph_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Nexora Commerce',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      username.isEmpty
                          ? 'A refined control room for sales, stock, and store operations.'
                          : 'Welcome back, $username. Your workspace opens directly into action.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: .68),
                          ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _navItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _NavTile(
                          item: _navItems[index],
                          selected: index == selectedIndex,
                          onTap: () => onSelect(index),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current sale',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: scheme.primary,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            formatQuantity(provider.cartCount),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: scheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'items in cart · ₹${provider.cartTotal.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final option in AppThemeOption.values) ...[
                          Expanded(
                            child: _ThemeChoice(
                              option: option,
                              selected: provider.themeOption == option,
                              compact: true,
                              onTap: () => provider.setThemeOption(option),
                            ),
                          ),
                          if (option != AppThemeOption.values.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: provider.logout,
                        icon: Icon(Icons.logout_rounded, color: scheme.error),
                        label: Text(
                          'Sign out',
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentShell extends StatelessWidget {
  const _ContentShell({
    required this.active,
    required this.child,
    required this.onQuickSale,
    required this.onOpenCart,
    required this.onOpenBusiness,
    this.compact = false,
  });

  final _Destination active;
  final Widget child;
  final VoidCallback onQuickSale;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenBusiness;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Ui.maxContentWidth),
        child: Container(
          margin: EdgeInsets.fromLTRB(
            0,
            compact ? 4 : 14,
            0,
            compact ? 84 : 18,
          ),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(compact ? 24 : 28),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: .08),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 24 : 28),
            child: Column(
              children: [
                _WorkspaceHeader(
                  active: active,
                  compact: compact,
                  onQuickSale: onQuickSale,
                  onOpenCart: onOpenCart,
                  onOpenBusiness: onOpenBusiness,
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                Expanded(
                  child: Container(
                    color: scheme.surface.withValues(alpha: .22),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.active,
    required this.onQuickSale,
    required this.onOpenCart,
    required this.onOpenBusiness,
    this.compact = false,
  });

  final _Destination active;
  final VoidCallback onQuickSale;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenBusiness;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.now();
    final provider = context.watch<AppProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 18,
        compact ? 14 : 16,
        compact ? 14 : 18,
        compact ? 12 : 14,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 16,
        spacing: 16,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 220 : 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_month(date.month)} ${date.day}, ${date.year}'.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  active.title,
                  style: compact ? textTheme.headlineSmall : textTheme.headlineMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  active.subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: .66),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onQuickSale,
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: Text(compact ? 'Sale' : 'New sale'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenBusiness,
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: Text(compact ? 'Store' : 'Business'),
              ),
              IconButton(
                onPressed: onOpenCart,
                tooltip: 'Current sale',
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surface,
                  padding: const EdgeInsets.all(12),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                icon: Badge(
                  isLabelVisible: provider.cartCount > 0,
                  label: Text(formatQuantity(provider.cartCount)),
                  backgroundColor: scheme.primary,
                  textColor: scheme.onPrimary,
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: scheme.onSurface.withValues(alpha: .82),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _month(int month) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][month - 1];
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.active,
    required this.onOpenCart,
    required this.onOpenBusiness,
    required this.onShowMore,
  });

  final _Destination active;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenBusiness;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_graph_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nexora Commerce',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  active.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: .64),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpenBusiness,
            tooltip: 'Business',
            style: IconButton.styleFrom(
              backgroundColor: scheme.surface.withValues(alpha: .84),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            icon: const Icon(Icons.storefront_outlined),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onShowMore,
            tooltip: 'Menu',
            style: IconButton.styleFrom(
              backgroundColor: scheme.surface.withValues(alpha: .84),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            icon: const Icon(Icons.grid_view_rounded),
          ),
        ],
      ),
    );
  }
}

class _BottomDock extends StatelessWidget {
  const _BottomDock({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = [
      ('Home', Icons.home_outlined, Icons.home_rounded),
      ('Sell', Icons.point_of_sale_outlined, Icons.point_of_sale_rounded),
      ('Items', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
      ('Groups', Icons.account_tree_outlined, Icons.account_tree_rounded),
      ('More', Icons.dashboard_customize_outlined, Icons.dashboard_customize_rounded),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: .10),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _DockItem(
                    label: items[i].$1,
                    icon: items[i].$2,
                    selectedIcon: items[i].$3,
                    selected: selectedIndex == i,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: .14) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: .68),
                size: 21,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: .68),
                      letterSpacing: .2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _Destination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: .15)
                : scheme.surface.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? scheme.primary.withValues(alpha: .28) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary
                      : scheme.surfaceContainerHighest.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected ? scheme.onPrimary : scheme.onSurface.withValues(alpha: .72),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: selected ? scheme.primary : scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: .58),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _Destination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: .14)
          : scheme.surfaceContainerHighest.withValues(alpha: .42),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: .72),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected ? scheme.primary : scheme.onSurface,
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

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.option,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final AppThemeOption option;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, swatch) = switch (option) {
      AppThemeOption.light => ('Ivory', AppColors.bronze),
      AppThemeOption.nightOwl => ('Noir', const Color(0xFFD9B687)),
      AppThemeOption.evergreen => ('Sage', const Color(0xFF556B5B)),
    };

    return Material(
      color: selected ? scheme.primary.withValues(alpha: .12) : scheme.surface,
      borderRadius: BorderRadius.circular(compact ? 18 : 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 10,
            vertical: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 18 : 20),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: compact
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: scheme.onSurface,
                            ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurface,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedIcon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
}
