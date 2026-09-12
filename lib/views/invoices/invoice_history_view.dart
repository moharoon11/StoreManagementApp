import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/platform_capabilities.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/workspace_ui.dart';

class InvoiceHistoryView extends StatefulWidget {
  const InvoiceHistoryView({super.key});

  @override
  State<InvoiceHistoryView> createState() => _InvoiceHistoryViewState();
}

class _InvoiceHistoryViewState extends State<InvoiceHistoryView> {
  bool _isLoading = true;
  List<dynamic> _invoices = [];
  Map<String, dynamic> _summary = {
    'totalTransactions': 0,
    'totalSale': 0.0,
    'balanceDue': 0.0,
  };
  AppProvider? _appProvider;
  int _seenInvoiceRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppProvider>();
    if (identical(provider, _appProvider)) return;
    _appProvider?.removeListener(_onAppStateChanged);
    _appProvider = provider;
    _seenInvoiceRevision = provider.invoiceRevision;
    provider.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    _appProvider?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    final provider = _appProvider;
    if (!mounted ||
        provider == null ||
        provider.invoiceRevision == _seenInvoiceRevision) {
      return;
    }
    _seenInvoiceRevision = provider.invoiceRevision;
    final latest = provider.latestInvoice;
    if (latest != null) {
      final id = latest['id'];
      setState(() {
        _invoices = [
          Map<String, dynamic>.from(latest),
          ..._invoices.where((invoice) =>
              Map<String, dynamic>.from(invoice as Map)['id'] != id),
        ];
      });
    }
    // Revalidate totals and server-side invoice formatting without making the
    // freshly completed sale wait for a manual refresh.
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchInvoices(),
      _fetchSummary(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchInvoices() async {
    try {
      final res = await ApiService.get(
        ApiConfig.invoices,
        queryParameters: {'pageSize': '100'},
      );
      if (!mounted) return;

      if (res is List) {
        final rows = List<dynamic>.from(res);
        final latest = _appProvider?.latestInvoice;
        final latestId = latest?['id'];
        _invoices = latest != null &&
                !rows.any((invoice) =>
                    Map<String, dynamic>.from(invoice as Map)['id'] == latestId)
            ? [Map<String, dynamic>.from(latest), ...rows]
            : rows;
        return;
      }

      if (res is Map && res['success'] == false) {
        return;
      }

      if (res is Map) {
        final rows = _extractInvoiceRows(res);
        final latest = _appProvider?.latestInvoice;
        final latestId = latest?['id'];
        // A newly completed checkout can reach this screen before an
        // eventually-consistent history endpoint includes it. Keep the local
        // checkout result visible until the server returns the same invoice.
        _invoices = latest != null &&
                !rows.any((invoice) =>
                    Map<String, dynamic>.from(invoice as Map)['id'] == latestId)
            ? [Map<String, dynamic>.from(latest), ...rows]
            : rows;
      }
    } catch (_) {}
  }

  Future<void> _fetchSummary() async {
    try {
      final res = await ApiService.get('${ApiConfig.invoices}/summary');
      if (res['success'] == true && mounted) {
        _summary = res['data'] ?? _summary;
      }
    } catch (_) {}
  }

  List<dynamic> _extractInvoiceRows(Map response) {
    final data = response['data'];
    if (data is List) {
      return List<dynamic>.from(data);
    }

    if (data is Map) {
      final candidates = [
        data['items'],
        data['invoices'],
        data['rows'],
        data['data'],
      ];
      for (final candidate in candidates) {
        if (candidate is List) {
          return List<dynamic>.from(candidate);
        }
      }
    }

    final topLevelItems = response['items'];
    if (topLevelItems is List) {
      return List<dynamic>.from(topLevelItems);
    }

    return const [];
  }

  Future<void> _downloadPdf(int invoiceId, String invoiceNum) async {
    try {
      final bytes = await InvoicePdfService.fetch(invoiceId);
      final wasSaved =
          await InvoicePdfService.save(bytes, 'Invoice_$invoiceNum.pdf');
      if (mounted && wasSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              PlatformCapabilities.isDesktop
                  ? 'PDF saved locally.'
                  : 'PDF saved successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading PDF: $e')),
      );
    }
  }

  void _openSaleEditModal(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SaleDetailModal(
        invoice: invoice,
        onUpdated: _loadData,
        onPdfRequested: () =>
            _downloadPdf(invoice['id'] as int, invoice['invoiceNumber'] ?? '1'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return WorkspacePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(
            eyebrow: 'Invoices',
            title: 'Sales history',
            description:
                'Track transactions, revisit customer details, and download invoice PDFs from a more compact ledger view.',
            action: OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          if (compact) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  label:
                      '${_summary['totalTransactions'] ?? _invoices.length} transactions',
                  color: Theme.of(context).colorScheme.primary,
                ),
                StatusPill(
                  label:
                      '₹${((_summary['totalSale'] ?? 0.0) as num).toStringAsFixed(2)} sale',
                  color: Theme.of(context).colorScheme.secondary,
                ),
                StatusPill(
                  label:
                      '₹${((_summary['balanceDue'] ?? 0.0) as num).toStringAsFixed(2)} due',
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else ...[
            AdaptiveWrapGrid(
              minItemWidth: 190,
              children: [
                StatTile(
                  label: 'Transactions',
                  value: '${_summary['totalTransactions'] ?? _invoices.length}',
                  icon: Icons.receipt_long_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                StatTile(
                  label: 'Total sale',
                  value:
                      '₹${((_summary['totalSale'] ?? 0.0) as num).toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                StatTile(
                  label: 'Balance due',
                  value:
                      '₹${((_summary['balanceDue'] ?? 0.0) as num).toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: SectionPanel(
              title: 'Invoice ledger',
              subtitle:
                  'Tap an invoice to edit details, review items, or save the PDF.',
              child: _isLoading
                  ? const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _invoices.isEmpty
                      ? const EmptyCanvas(
                          icon: Icons.receipt_long_outlined,
                          title: 'No sales records found',
                          detail:
                              'Completed checkouts will appear here automatically.',
                        )
                      : ListView.separated(
                          itemCount: _invoices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final invoice = Map<String, dynamic>.from(
                                _invoices[index] as Map);
                            return _InvoiceCard(
                              invoice: invoice,
                              onTap: () => _openSaleEditModal(invoice),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.onTap,
  });

  final Map<String, dynamic> invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final customerName = (invoice['customerName'] ?? '').toString().trim();
    final nameDisplay = customerName.isEmpty || customerName == 'NO_NAME'
        ? 'Walk-in customer'
        : customerName;
    final totalAmount = (invoice['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final balanceDue = (invoice['balanceDue'] as num?)?.toDouble() ?? 0.0;
    final dateStr =
        (invoice['invoiceDate'] ?? invoice['createdAt'] ?? '').toString();
    final dateFormatted =
        dateStr.contains('T') ? dateStr.split('T').first : dateStr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(22),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 540;
              final amountText = '₹${totalAmount.toStringAsFixed(2)}';
              final balanceText = '₹${balanceDue.toStringAsFixed(2)}';

              Widget amountColumn() => Column(
                    crossAxisAlignment: narrow
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Text(
                        amountText,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      StatusPill(
                        label:
                            balanceDue > 0 ? 'Due $balanceText' : 'Fully paid',
                        color: balanceDue > 0 ? scheme.error : scheme.secondary,
                      ),
                    ],
                  );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _InvoiceMark(
                            color:
                                balanceDue > 0 ? scheme.error : scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(nameDisplay,
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${invoice['invoiceNumber'] ?? 'Sale ${invoice['id']}'} · $dateFormatted',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: .6),
                          ),
                    ),
                    const SizedBox(height: 12),
                    amountColumn(),
                  ],
                );
              }

              return Row(
                children: [
                  _InvoiceMark(
                      color: balanceDue > 0 ? scheme.error : scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nameDisplay,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          '${invoice['invoiceNumber'] ?? 'Sale ${invoice['id']}'} · $dateFormatted',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: scheme.onSurface.withValues(alpha: .6),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  amountColumn(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InvoiceMark extends StatelessWidget {
  const _InvoiceMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.receipt_long_outlined, color: color, size: 21),
      );
}

class _SaleDetailModal extends StatefulWidget {
  const _SaleDetailModal({
    required this.invoice,
    required this.onUpdated,
    required this.onPdfRequested,
  });

  final Map<String, dynamic> invoice;
  final VoidCallback onUpdated;
  final VoidCallback onPdfRequested;

  @override
  State<_SaleDetailModal> createState() => _SaleDetailModalState();
}

class _SaleDetailModalState extends State<_SaleDetailModal> {
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _amountReceivedController;
  late bool _isReceived;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final customerName = (widget.invoice['customerName'] ?? '').toString();
    _nameController = TextEditingController(
        text: customerName == 'NO_NAME' ? '' : customerName);
    _mobileController = TextEditingController(
      text: (widget.invoice['customerMobileNumber'] ?? '').toString(),
    );

    final grandTotal =
        (widget.invoice['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final amountReceived =
        (widget.invoice['amountReceived'] as num?)?.toDouble() ?? grandTotal;
    _isReceived = (widget.invoice['isReceived'] as bool?) ??
        (amountReceived >= grandTotal);
    _amountReceivedController =
        TextEditingController(text: amountReceived.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _amountReceivedController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final grandTotal =
          (widget.invoice['grandTotal'] as num?)?.toDouble() ?? 0.0;
      final amountReceived = double.tryParse(_amountReceivedController.text) ??
          (_isReceived ? grandTotal : 0.0);

      final res = await ApiService.put(
        '${ApiConfig.invoices}/${widget.invoice['id']}',
        {
          'customerName': _nameController.text.trim(),
          'customerMobileNumber': _mobileController.text.trim(),
          'isReceived': _isReceived,
          'amountReceived': amountReceived,
        },
      );

      if (res['success'] == true) {
        widget.onUpdated();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale updated successfully!')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to update sale.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteInvoice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sale'),
        content:
            const Text('Are you sure you want to delete this sale invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final res = await ApiService.delete(
          '${ApiConfig.invoices}/${widget.invoice['id']}');
      if (res['success'] == true) {
        widget.onUpdated();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale deleted.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal =
        (widget.invoice['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final amountReceived = double.tryParse(_amountReceivedController.text) ??
        (_isReceived ? grandTotal : 0.0);
    final balanceDue =
        (grandTotal - amountReceived).clamp(0.0, double.infinity);
    final items = (widget.invoice['items'] as List?) ?? [];
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 860;

    return Container(
      height: MediaQuery.sizeOf(context).height * .92,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sale ${widget.invoice['id']}',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        (widget.invoice['invoiceDate'] ??
                                widget.invoice['createdAt'] ??
                                '')
                            .toString()
                            .split('T')
                            .first,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: .62),
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onPdfRequested,
                  icon:
                      Icon(Icons.picture_as_pdf_outlined, color: scheme.error),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SaleMetaPanel(
                                nameController: _nameController,
                                mobileController: _mobileController,
                                amountReceivedController:
                                    _amountReceivedController,
                                isReceived: _isReceived,
                                grandTotal: grandTotal,
                                balanceDue: balanceDue,
                                onChangedReceived: (value) {
                                  setState(() {
                                    _isReceived = value;
                                    if (_isReceived) {
                                      _amountReceivedController.text =
                                          grandTotal.toStringAsFixed(2);
                                    } else {
                                      _amountReceivedController.text = '0.00';
                                    }
                                  });
                                },
                                onAmountChanged: () => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ItemLedgerPanel(
                                items: items,
                                grandTotal: grandTotal,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _SaleMetaPanel(
                              nameController: _nameController,
                              mobileController: _mobileController,
                              amountReceivedController:
                                  _amountReceivedController,
                              isReceived: _isReceived,
                              grandTotal: grandTotal,
                              balanceDue: balanceDue,
                              onChangedReceived: (value) {
                                setState(() {
                                  _isReceived = value;
                                  if (_isReceived) {
                                    _amountReceivedController.text =
                                        grandTotal.toStringAsFixed(2);
                                  } else {
                                    _amountReceivedController.text = '0.00';
                                  }
                                });
                              },
                              onAmountChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            _ItemLedgerPanel(
                              items: items,
                              grandTotal: grandTotal,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _deleteInvoice,
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleMetaPanel extends StatelessWidget {
  const _SaleMetaPanel({
    required this.nameController,
    required this.mobileController,
    required this.amountReceivedController,
    required this.isReceived,
    required this.grandTotal,
    required this.balanceDue,
    required this.onChangedReceived,
    required this.onAmountChanged,
  });

  final TextEditingController nameController;
  final TextEditingController mobileController;
  final TextEditingController amountReceivedController;
  final bool isReceived;
  final double grandTotal;
  final double balanceDue;
  final ValueChanged<bool> onChangedReceived;
  final VoidCallback onAmountChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionPanel(
          title: 'Customer details',
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Customer name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionPanel(
          title: 'Payment summary',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total amount'),
                  Text(
                    '₹${grandTotal.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: isReceived,
                    onChanged: (value) => onChangedReceived(value ?? true),
                  ),
                  const Text('Received'),
                  const Spacer(),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: amountReceivedController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => onAmountChanged(),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        labelText: 'Amount',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance due'),
                  StatusPill(
                    label: '₹${balanceDue.toStringAsFixed(2)}',
                    color: balanceDue > 0
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.secondary,
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

class _ItemLedgerPanel extends StatelessWidget {
  const _ItemLedgerPanel({
    required this.items,
    required this.grandTotal,
  });

  final List<dynamic> items;
  final double grandTotal;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Item ledger',
      subtitle:
          '${items.length} billed item type${items.length == 1 ? '' : 's'}',
      child: Column(
        children: [
          if (items.isEmpty)
            const Text('No line items were stored for this sale.')
          else
            ...items.map((entry) {
              final item = entry as Map;
              final price = (item['sellingPrice'] as num?)?.toDouble() ?? 0.0;
              final qty = quantityValue(item['quantity']);
              final total =
                  (item['total'] as num?)?.toDouble() ?? (price * qty);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item['productName'] ?? 'Item').toString(),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${formatQuantity(qty)} ${item['unit'] ?? 'Piece'} × ₹${price.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '₹${total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 4),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand total'),
              Text(
                '₹${grandTotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
