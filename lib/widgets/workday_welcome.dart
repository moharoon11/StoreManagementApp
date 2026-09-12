import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'ui_breakpoints.dart';

/// Day-opening page. Same flow as before (pick a task -> workspace) but in
/// the ledger visual language: paper background, hairline rules, ruled rows.
class WorkdayWelcome extends StatelessWidget {
  const WorkdayWelcome({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().username;
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final now = DateTime.now();
    final date = '${now.day} ${_month(now.month)} ${now.year}';
    return Scaffold(
      backgroundColor: scheme.brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Ui.constrain(
            Padding(
              padding: EdgeInsets.all(compact ? 20 : 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 10,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.account_balance_outlined,
                              color: scheme.onPrimary, size: 20),
                        ),
                        const SizedBox(width: 11),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('NEXORA',
                                  style: TextStyle(
                                      letterSpacing: 2.4,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: scheme.onSurface)),
                              Text(date.toUpperCase(),
                                  style: TextStyle(
                                      letterSpacing: 1.6,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                      color: scheme.onSurface
                                          .withValues(alpha: .5))),
                            ]),
                      ]),
                      OutlinedButton.icon(
                        onPressed: onContinue,
                        icon: const Icon(Icons.east_rounded, size: 16),
                        label: const Text('Open ledger'),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 22 : 44),
                  Container(
                    height: 3,
                    width: 44,
                    decoration: BoxDecoration(
                      color: scheme.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Good day${user.isEmpty ? '' : ', $user'}.',
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 26 : 36,
                        letterSpacing: 0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Three entries to begin with. Pick one to open the day book.',
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .6),
                        fontSize: 14,
                        fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(builder: (context, constraints) {
                    final cols = Ui.columnsForWidth(
                        constraints.maxWidth, 260,
                        minColumns: 1, maxColumns: 3);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 168,
                      ),
                      itemCount: 3,
                      itemBuilder: (context, i) =>
                          _JourneyRow(entry: _entries(context)[i]),
                    );
                  }),
                  const SizedBox(height: 16),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 10),
                  Text(
                      'You can move between every section at any time from the ledger rail or the index.',
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: .55),
                          fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_Entry> _entries(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      _Entry('01', Icons.point_of_sale_outlined, scheme.primary,
          'Record a sale', 'Bill goods and close the checkout.', () {
        context.read<AppProvider>().setNavIndex(1);
        onContinue();
      }),
      _Entry('02', Icons.inventory_2_outlined, scheme.secondary,
          'Check the shelves', 'Prices, stock levels and favourites.', () {
        context.read<AppProvider>().setNavIndex(2);
        onContinue();
      }),
      _Entry('03', Icons.auto_graph_outlined, scheme.primary, 'Read the day',
          'Takings, alerts and fast movers.', () {
        context.read<AppProvider>().setNavIndex(0);
        onContinue();
      }),
    ];
  }

  String _month(int m) => const [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ][m.clamp(1, 12)];
}

class _Entry {
  const _Entry(
      this.no, this.icon, this.color, this.title, this.text, this.onTap);
  final String no, title, text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// Horizontal ruled row instead of the old tall card.
class _JourneyRow extends StatelessWidget {
  const _JourneyRow({required this.entry});
  final _Entry entry;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(
                width: 4,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ),
                      Text(entry.no,
                          style: TextStyle(
                              color:
                                  scheme.onSurface.withValues(alpha: .4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 5),
                    Text(entry.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: .6),
                            fontSize: 12,
                            height: 1.4)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('Open entry',
                          style: TextStyle(
                              color: scheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 5),
                      Icon(Icons.east_rounded,
                          color: scheme.primary, size: 15)
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}
