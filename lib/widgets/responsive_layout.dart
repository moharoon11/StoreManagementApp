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
    final compact = MediaQuery.sizeOf(context).width < Ui.compactMax;
    final active = _navItems[provider.selectedNavIndex];
    final content = IndexedStack(
      index: provider.selectedNavIndex,
      children: _views,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: compact
              ? _CompactWorkspace(
                  active: active,
                  child: content,
                  onOpenCart: () => openCart(context),
                  onShowMore: () => _showMore(context),
                )
              : _DesktopWorkspace(
                  active: active,
                  selectedIndex: provider.selectedNavIndex,
                  onSelect: provider.setNavIndex,
                  child: content,
                  onQuickSale: () => provider.setNavIndex(1),
                  onOpenCart: () => openCart(context),
                  onOpenBusiness: () => provider.setNavIndex(7),
                  onShowMore: () => _showMore(context),
                ),
        ),
      ),
      bottomNavigationBar: compact
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
          final crossAxisCount = width >= 720 ? 3 : 2;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workspace menu',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Jump between tools, switch themes, or sign out.',
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
                    childAspectRatio: width >= 720 ? 2.05 : 1.85,
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
                  const SizedBox(height: 18),
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 480;
                      final first = _ThemeChoice(
                        option: AppThemeOption.light,
                        selected: provider.themeOption == AppThemeOption.light,
                        onTap: () => provider.setThemeOption(
                          AppThemeOption.light,
                        ),
                        compact: true,
                      );
                      final second = _ThemeChoice(
                        option: AppThemeOption.nightOwl,
                        selected:
                            provider.themeOption == AppThemeOption.nightOwl,
                        onTap: () => provider.setThemeOption(
                          AppThemeOption.nightOwl,
                        ),
                        compact: true,
                      );
                      final third = _ThemeChoice(
                        option: AppThemeOption.evergreen,
                        selected:
                            provider.themeOption == AppThemeOption.evergreen,
                        onTap: () => provider.setThemeOption(
                          AppThemeOption.evergreen,
                        ),
                        compact: true,
                      );

                      if (narrow) {
                        return Column(
                          children: [
                            SizedBox(width: double.infinity, child: first),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: second),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: third),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: first),
                          const SizedBox(width: 10),
                          Expanded(child: second),
                          const SizedBox(width: 10),
                          Expanded(child: third),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
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
    required this.onShowMore,
  });

  final _Destination active;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget child;
  final VoidCallback onQuickSale;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenBusiness;
  final VoidCallback onShowMore;

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
            onShowMore: onShowMore,
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
    required this.onShowMore,
  });

  final _Destination active;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onQuickSale;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenBusiness;
  final VoidCallback onShowMore;

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
            if (provider.username.trim().isNotEmpty)
              _UserBadge(username: provider.username.trim()),
            OutlinedButton.icon(
              onPressed: onOpenBusiness,
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Business'),
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
            _HeaderActionIcon(
              onPressed: onShowMore,
              tooltip: 'Menu',
              child: const Icon(Icons.tune_rounded),
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
    required this.onShowMore,
  });

  final _Destination active;
  final Widget child;
  final VoidCallback onOpenCart;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          _CompactHeader(
            active: active,
            onOpenCart: onOpenCart,
            onShowMore: onShowMore,
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
    required this.onShowMore,
  });

  final _Destination active;
  final VoidCallback onOpenCart;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final phone = Ui.isPhone(context);

    return SurfacePanel(
      padding: EdgeInsets.all(phone ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: phone ? 40 : 44,
                height: phone ? 40 : 44,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(phone ? 14 : 16),
                ),
                child: Icon(Icons.auto_graph_rounded,
                    color: Colors.white, size: phone ? 20 : 22),
              ),
              SizedBox(width: phone ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nexora Commerce',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: phone
                          ? Theme.of(context).textTheme.titleSmall
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatToday(DateTime.now()).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            letterSpacing: phone ? 1.2 : 1.6,
                          ),
                    ),
                  ],
                ),
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
              const SizedBox(width: 6),
              _HeaderActionIcon(
                onPressed: onShowMore,
                tooltip: 'Menu',
                child: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          SizedBox(height: phone ? 10 : 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(label: active.title, color: scheme.primary),
            ],
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
                'Nexora Commerce',
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
    final radius = compact ? 22.0 : 28.0;

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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: SurfacePanel(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NavigationBar(
              height: 68,
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
          padding: const EdgeInsets.all(16),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                      maxLines: 2,
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
      AppThemeOption.light => ('Slate', AppColors.brand),
      AppThemeOption.nightOwl => ('Midnight', const Color(0xFF67E8F9)),
      AppThemeOption.evergreen => ('Spruce', const Color(0xFF1F6F5C)),
    };

    return Material(
      color: selected ? scheme.primary.withValues(alpha: .12) : scheme.surface,
      borderRadius: BorderRadius.circular(compact ? 18 : 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 18 : 20),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: compact ? 14 : 16,
                height: compact ? 14 : 16,
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
          ),
        ),
      ),
    );
  }
}

class _UserBadge extends StatelessWidget {
  const _UserBadge({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline_rounded, size: 18, color: scheme.secondary),
          const SizedBox(width: 8),
          Text(
            username,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                ),
          ),
        ],
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

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surface.withValues(alpha: .92),
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
