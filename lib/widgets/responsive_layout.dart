import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/quantity_utils.dart';
import '../views/billing/pos_checkout_view.dart';
import '../views/categories/categories_view.dart';
import '../views/dashboard/dashboard_view.dart';
import '../views/invoices/invoice_history_view.dart';
import '../views/invoices/customer_credit_invoices_view.dart';
import '../views/payments/payment_transactions_view.dart';
import '../views/products/products_view.dart';
import '../views/reports/sales_reports_view.dart';
import '../views/stock/stock_management_view.dart';
import '../views/store/store_profile_view.dart';
import 'cart_checkout.dart';
import 'ui_breakpoints.dart';
import 'workspace_ui.dart';

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
    title: 'Credit',
    subtitle: 'Pending customer balances',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
  ),
  _Destination(
    title: 'Payments',
    subtitle: 'Read-only payment activity',
    icon: Icons.payments_outlined,
    selectedIcon: Icons.payments_rounded,
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
    CustomerCreditInvoicesView(),
    PaymentTransactionsView(),
    StockManagementView(),
    SalesReportsView(),
    StoreProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final compact = MediaQuery.sizeOf(context).width < Ui.compactMax;
    final isFullScreenReport = compact && provider.selectedNavIndex == 4;
    final active = _navItems[provider.selectedNavIndex];
    // Screens are recreated only when opened. This keeps every catalogue,
    // report, and stock view current without asking the user to refresh.
    final content = KeyedSubtree(
      key: ValueKey(provider.selectedNavIndex),
      child: _views[provider.selectedNavIndex],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: isFullScreenReport
          ? const InvoiceHistoryView(fullScreen: true)
          : WorkspaceBackdrop(
              child: SafeArea(
                child: compact
                    ? _CompactWorkspace(
                        active: active,
                        child: content,
                        onOpenCart: () => openCart(context),
                        onOpenBusiness: () => provider.setNavIndex(9),
                      )
                    : _DesktopWorkspace(
                        active: active,
                        selectedIndex: provider.selectedNavIndex,
                        onSelect: provider.setNavIndex,
                        child: content,
                        onQuickSale: () => provider.setNavIndex(1),
                        onOpenCart: () => openCart(context),
                        onOpenBusiness: () => provider.setNavIndex(9),
                      ),
              ),
            ),
      bottomNavigationBar: compact && !isFullScreenReport
          ? _BottomWorkspaceBar(
              selectedIndex: _bottomIndex(provider.selectedNavIndex),
              onSelect: (index) {
                if (index == 4) {
                  _showMore(context);
                  return;
                }
                provider.setNavIndex([0, 1, 2, 3][index]);
              },
            )
          : null,
    );
  }

  static int _bottomIndex(int index) =>
      switch (index) { 0 => 0, 1 => 1, 2 => 2, 3 => 3, _ => 4 };

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer<AppProvider>(
        builder: (context, provider, _) {
          final scheme = Theme.of(context).colorScheme;
          final width = MediaQuery.sizeOf(context).width;
          // Two columns remain easy to scan on phones while compact tiles keep
          // the full menu inside short device heights.
          final crossAxisCount = width >= 720 ? 3 : 2;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .88,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workspace menu',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Jump between tools or sign out.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: .66),
                          ),
                    ),
                    const SizedBox(height: 18),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: crossAxisCount,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: width >= 720
                          ? 2.45
                          : width < 450
                              ? 2.05
                              : 2.3,
                      children: [
                        for (var index = 0; index < _navItems.length; index++)
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
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        provider.themeOption == AppThemeOption.nightOwl
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: scheme.primary,
                      ),
                      title: const Text('Dark mode'),
                      subtitle:
                          const Text('Use the softer low-light workspace'),
                      value: provider.themeOption == AppThemeOption.nightOwl,
                      onChanged: (enabled) => provider.setThemeOption(
                        enabled
                            ? AppThemeOption.nightOwl
                            : AppThemeOption.light,
                      ),
                    ),
                    const SizedBox(height: 8),
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
        },
      ),
    );
  }
}

class _DesktopWorkspace extends StatelessWidget {
  const _DesktopWorkspace({
    required this.active,
    required this.selectedIndex,
    required this.onSelect,
    required this.child,
    required this.onQuickSale,
    required this.onOpenCart,
    required this.onOpenBusiness,
  });

  final _Destination active;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget child;
  final VoidCallback onQuickSale;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenBusiness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: [
          _WorkspaceCommandBar(
            active: active,
            selectedIndex: selectedIndex,
            onSelect: onSelect,
            onQuickSale: onQuickSale,
            onOpenCart: onOpenCart,
            onOpenBusiness: onOpenBusiness,
          ),
          const SizedBox(height: 18),
          Expanded(child: _ContentViewport(child: child)),
        ],
      ),
    );
  }
}

class _WorkspaceCommandBar extends StatelessWidget {
  const _WorkspaceCommandBar({
    required this.active,
    required this.selectedIndex,
    required this.onSelect,
    required this.onQuickSale,
    required this.onOpenCart,
    required this.onOpenBusiness,
  });

  final _Destination active;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onQuickSale;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenBusiness;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();

    Widget actions() => Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StoreIdentityButton(
              username: provider.username,
              storeName: provider.storeName,
              logoUrl: provider.storeLogoUrl,
              onPressed: onOpenBusiness,
            ),
            FilledButton.icon(
              onPressed: onQuickSale,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('New sale'),
            ),
            _HeaderActionIcon(
              onPressed: onOpenCart,
              tooltip: 'Current sale',
              child: Badge(
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
        );

    return SurfacePanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1120;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BrandSummary(active: active),
                          const SizedBox(height: 16),
                          actions(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _BrandSummary(active: active)),
                          const SizedBox(width: 16),
                          Flexible(child: actions()),
                        ],
                      ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var index = 0; index < _navItems.length; index++)
                        _WorkspaceTab(
                          item: _navItems[index],
                          selected: selectedIndex == index,
                          onTap: () => onSelect(index),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompactWorkspace extends StatelessWidget {
  const _CompactWorkspace({
    required this.active,
    required this.child,
    required this.onOpenCart,
    required this.onOpenBusiness,
  });

  final _Destination active;
  final Widget child;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenBusiness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Column(
        children: [
          _CompactHeader(
            active: active,
            onOpenCart: onOpenCart,
            onOpenBusiness: onOpenBusiness,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _ContentViewport(
              compact: true,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.active,
    required this.onOpenCart,
    required this.onOpenBusiness,
  });

  final _Destination active;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenBusiness;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final phone = Ui.isPhone(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(phone ? 2 : 4, 2, phone ? 2 : 4, 2),
      child: Row(
        children: [
          Container(
            width: phone ? 36 : 40,
            height: phone ? 36 : 40,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(phone ? 12 : 14),
            ),
            child: Icon(
              Icons.auto_graph_rounded,
              color: Colors.white,
              size: phone ? 18 : 20,
            ),
          ),
          SizedBox(width: phone ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BillMate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: phone
                      ? Theme.of(context).textTheme.titleSmall
                      : Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${active.title} · ${_formatToday(DateTime.now())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: .62),
                      ),
                ),
              ],
            ),
          ),
          _StoreIdentityButton(
            username: provider.username,
            storeName: provider.storeName,
            logoUrl: provider.storeLogoUrl,
            onPressed: onOpenBusiness,
            compact: true,
          ),
          const SizedBox(width: 4),
          _HeaderActionIcon(
            onPressed: onOpenCart,
            tooltip: 'Current sale',
            child: Badge(
              isLabelVisible: provider.cartCount > 0,
              label: Text(formatQuantity(provider.cartCount)),
              backgroundColor: scheme.primary,
              textColor: scheme.onPrimary,
              child: Icon(
                Icons.shopping_bag_outlined,
                color: scheme.onSurface.withValues(alpha: .82),
                size: phone ? 18 : 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandSummary extends StatelessWidget {
  const _BrandSummary({required this.active});

  final _Destination active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.auto_graph_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BillMate',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'A cleaner cross-platform control center for retail operations.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: .72),
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatusPill(
                    label: _formatToday(DateTime.now()),
                    color: scheme.primary,
                  ),
                  StatusPill(
                    label: active.title,
                    color: scheme.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContentViewport extends StatelessWidget {
  const _ContentViewport({
    required this.child,
    this.compact = false,
  });

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = compact ? 18.0 : 28.0;

    if (compact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _blend(scheme.surface, scheme.primary, .006),
          ),
          child: Column(
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      scheme.secondary,
                      scheme.tertiary,
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: _blend(scheme.surface, scheme.primary, .006),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SurfacePanel(
      padding: EdgeInsets.zero,
      color: _blend(scheme.surface, scheme.primary, .012),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          children: [
            Container(
              height: compact ? 6 : 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    scheme.secondary,
                    scheme.tertiary,
                  ],
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: _blend(scheme.surface, scheme.primary, .01),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomWorkspaceBar extends StatelessWidget {
  const _BottomWorkspaceBar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phone = Ui.isPhone(context);

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: .035),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          height: phone ? 60 : 64,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale_rounded),
              label: 'Sell',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              selectedIcon: Icon(Icons.account_tree_rounded),
              label: 'Categories',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_customize_outlined),
              selectedIcon: Icon(Icons.dashboard_customize_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceTab extends StatelessWidget {
  const _WorkspaceTab({
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

    return Tooltip(
      message: item.subtitle,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: .14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: .22)
                    : scheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 18,
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: .68),
                ),
                const SizedBox(width: 10),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? scheme.primary
                            : scheme.onSurface.withValues(alpha: .82),
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
          : scheme.surfaceContainerHighest.withValues(alpha: .34),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary
                      : scheme.surface.withValues(alpha: .84),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected
                      ? scheme.onPrimary
                      : scheme.onSurface.withValues(alpha: .72),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _StoreIdentityButton extends StatelessWidget {
  const _StoreIdentityButton({
    required this.username,
    required this.storeName,
    required this.logoUrl,
    required this.onPressed,
    this.compact = false,
  });

  final String username;
  final String storeName;
  final String logoUrl;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final accountName = username.trim().isEmpty ? 'Business' : username.trim();
    final displayName =
        storeName.trim().isEmpty ? accountName : storeName.trim();
    final avatar = _StoreIdentityAvatar(
      logoUrl: logoUrl,
      fallback: displayName,
      compact: compact,
    );

    return Tooltip(
      message: 'Open business profile',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 10,
              vertical: compact ? 4 : 7,
            ),
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: compact
                ? avatar
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      avatar,
                      const SizedBox(width: 9),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            if (displayName != accountName)
                              Text(
                                accountName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurface
                                          .withValues(alpha: .62),
                                    ),
                              ),
                          ],
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

class _StoreIdentityAvatar extends StatelessWidget {
  const _StoreIdentityAvatar({
    required this.logoUrl,
    required this.fallback,
    required this.compact,
  });

  final String logoUrl;
  final String fallback;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 38.0;
    final scheme = Theme.of(context).colorScheme;
    final initial =
        fallback.trim().isEmpty ? 'B' : fallback.trim()[0].toUpperCase();
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: logoUrl.trim().isEmpty
            ? ColoredBox(
                color: scheme.primary,
                child: Center(
                  child: Text(
                    initial,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              )
            : Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: scheme.primary,
                  child: Center(
                    child: Text(initial,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            )),
                  ),
                ),
              ),
      ),
    );
  }
}

class _HeaderActionIcon extends StatelessWidget {
  const _HeaderActionIcon({
    required this.onPressed,
    required this.tooltip,
    required this.child,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phone = Ui.isPhone(context);

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surface.withValues(alpha: .88),
        minimumSize: Size.square(phone ? 40 : 44),
        padding: EdgeInsets.zero,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      icon: child,
    );
  }
}

String _formatToday(DateTime date) {
  const months = [
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
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
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

Color _blend(Color a, Color b, double amount) => Color.lerp(a, b, amount) ?? a;
