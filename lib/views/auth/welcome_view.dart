import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../widgets/workspace_ui.dart';

/// The first screen shown before authentication. It is intentionally built
/// from app-native widgets so it stays crisp at every phone size.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: EdgeInsets.fromLTRB(compact ? 24 : 32, 20,
                    compact ? 24 : 32, 22),
                child: Column(
                  children: [
                    const Spacer(),
                    _BillMateMark(color: scheme.primary),
                    const SizedBox(height: 28),
                    Text(
                      'BillMate',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Simple billing.\nSmarter business.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 32),
                    const Row(
                      children: [
                        Expanded(
                          child: _WelcomeFeature(
                            icon: Icons.receipt_long_outlined,
                            label: 'Create bills',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _WelcomeFeature(
                            icon: Icons.inventory_2_outlined,
                            label: 'Manage items',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _WelcomeFeature(
                            icon: Icons.bar_chart_rounded,
                            label: 'Track sales',
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),
                    FilledButton(
                      onPressed: () =>
                          context.read<AppProvider>().completeWelcome(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: const StadiumBorder(),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Get started'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BillMateMark extends StatelessWidget {
  const _BillMateMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 154,
        height: 150,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: .1,
              child: Container(
                width: 96,
                height: 122,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: color, width: 4),
                ),
                child: Icon(Icons.receipt_long_rounded, color: color, size: 62),
              ),
            ),
            Positioned(
              left: 2,
              bottom: 2,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color, Theme.of(context).colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.currency_rupee_rounded,
                    color: Colors.white, size: 39),
              ),
            ),
          ],
        ),
      );
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Icon(icon, size: 25, color: scheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 0,
                color: scheme.onSurface.withValues(alpha: .7),
              ),
        ),
      ],
    );
  }
}
