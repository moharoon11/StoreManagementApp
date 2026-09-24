import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';

class StockManagementView extends StatefulWidget {
  const StockManagementView({super.key});

  @override
  State<StockManagementView> createState() => _StockManagementViewState();
}

class _StockManagementViewState extends State<StockManagementView> {
  bool _isLoading = true;
  List<dynamic> _movements = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _fetchMovements();
  }

  Future<void> _fetchMovements() async {
    try {
      final res = await ApiService.get(ApiConfig.stockMovements);
      if (!mounted) return;
      final data = res['data'];
      final movements = data is List
          ? data
          : data is Map
              ? (data['items'] ?? data['movements'] ?? []) as List
              : <dynamic>[];
      setState(() {
        _movements = movements;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageIntro(
            eyebrow: 'Stock',
            title: 'Inventory movements',
            description:
                'Review every sale, return, and inventory update in one reliable log.',
          ),
          const SizedBox(height: 16),
          AdaptiveWrapGrid(
            minItemWidth: 190,
            children: [
              StatTile(
                label: 'Movement rows',
                value: '${_movements.length}',
                icon: Icons.swap_vert_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SectionPanel(
              title: 'Movement log',
              subtitle:
                  'Recent sale, return, and stock updates across the store.',
              child: _isLoading
                  ? const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _movements.isEmpty
                      ? const EmptyCanvas(
                          icon: Icons.inventory_2_outlined,
                          title: 'No stock movement records found',
                          detail:
                              'Sales, returns, and product updates will appear here.',
                        )
                      : ListView.separated(
                          itemCount: _movements.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final movement = Map<String, dynamic>.from(
                                _movements[index] as Map);
                            return _MovementCard(movement: movement);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});

  final Map<String, dynamic> movement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAddition = quantityValue(movement['quantityChanged']) > 0;
    final unit = (movement['unit'] ?? 'Piece').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final badge = StatusPill(
            label:
                '${isAddition ? '+' : ''}${formatQuantity(movement['quantityChanged'])} $unit',
            color: isAddition ? scheme.secondary : scheme.error,
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MovementIcon(isAddition: isAddition),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (movement['productName'] ?? '').toString(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Prev: ${formatQuantity(movement['previousQuantity'])} $unit → New: ${formatQuantity(movement['newQuantity'])} $unit',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  (movement['reason'] ?? '').toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                      ),
                ),
                const SizedBox(height: 10),
                badge,
              ],
            );
          }

          return Row(
            children: [
              _MovementIcon(isAddition: isAddition),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (movement['productName'] ?? '').toString(),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prev: ${formatQuantity(movement['previousQuantity'])} $unit → New: ${formatQuantity(movement['newQuantity'])} $unit',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (movement['reason'] ?? '').toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              badge,
            ],
          );
        },
      ),
    );
  }
}

class _MovementIcon extends StatelessWidget {
  const _MovementIcon({required this.isAddition});

  final bool isAddition;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: (isAddition ? scheme.secondary : scheme.error)
            .withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        isAddition ? Icons.add_rounded : Icons.remove_rounded,
        color: isAddition ? scheme.secondary : scheme.error,
      ),
    );
  }
}
