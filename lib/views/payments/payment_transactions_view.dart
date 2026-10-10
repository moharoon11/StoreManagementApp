import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../widgets/ui_breakpoints.dart';
import '../../widgets/workspace_ui.dart';

typedef _PaymentTransactionList = List<_PaymentTransaction>;

/// A read-only ledger assembled from the invoice and customer-credit APIs.
/// It deliberately contains no mutation controls: invoices and credit remain
/// managed in their own workspaces.
class PaymentTransactionsView extends StatefulWidget {
  const PaymentTransactionsView({super.key});

  @override
  State<PaymentTransactionsView> createState() =>
      _PaymentTransactionsViewState();
}

class _PaymentTransactionsViewState extends State<PaymentTransactionsView> {
  final _search = TextEditingController();
  bool _loading = true;
  String _query = '';
  _TransactionFilter _filter = _TransactionFilter.all;
  DateTime? _fromDate;
  DateTime? _toDate;
  List<_PaymentTransaction> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<_PaymentTransactionList>([
        _safeLoad(_loadInvoices()),
        _safeLoad(_loadCredit()),
      ]);
      final invoices = results[0];
      final credit = results[1];
      if (mounted) {
        setState(() {
          _transactions = [...invoices, ...credit]
            ..sort((a, b) => b.date.compareTo(a.date));
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_PaymentTransactionList> _safeLoad(
      Future<_PaymentTransactionList> request) async {
    try {
      return await request;
    } catch (_) {
      // Invoice and credit history are independent. Show whichever source
      // remains available rather than failing the whole payment timeline.
      return const [];
    }
  }

  Future<List<_PaymentTransaction>> _loadInvoices() async {
    final query = <String, String>{'PageSize': '500'};
    if (_fromDate != null) query['FromDate'] = _fromDate!.toIso8601String();
    if (_toDate != null) {
      query['ToDate'] = DateTime(
        _toDate!.year,
        _toDate!.month,
        _toDate!.day,
        23,
        59,
        59,
      ).toIso8601String();
    }
    final response =
        await ApiService.get(ApiConfig.invoices, queryParameters: query);
    final rows = _rows(response);
    return rows
        .map((row) {
          final total = _number(row['grandTotal']);
          final received = row.containsKey('amountReceived')
              ? _number(row['amountReceived'])
              : total;
          return _PaymentTransaction(
            id: 'invoice-${row['id'] ?? row['invoiceNumber']}',
            date: _dateOf(row['invoiceDate'] ?? row['createdAt']),
            title: received >= total && total > 0
                ? 'Sale received'
                : 'Sale payment pending',
            customer: _customerOf(row),
            reference: (row['invoiceNumber'] ?? 'Invoice ${row['id'] ?? ''}')
                .toString(),
            amount: received,
            direction: _Direction.incoming,
            status: received >= total && total > 0
                ? _TransactionStatus.completed
                : received > 0
                    ? _TransactionStatus.partial
                    : _TransactionStatus.pending,
            details: {
              'Invoice total': _money(total),
              'Amount received': _money(received),
              'Balance due': _money(_number(row['balanceDue'])),
              if ((row['customerMobileNumber'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty)
                'Mobile': row['customerMobileNumber'].toString(),
            },
          );
        })
        .where((item) =>
            item.amount > 0 || item.status == _TransactionStatus.pending)
        .toList();
  }

  Future<List<_PaymentTransaction>> _loadCredit() async {
    final response = await ApiService.get(
      ApiConfig.customerCreditInvoices,
      queryParameters: const {'pendingOnly': 'false'},
    );
    final invoices = response is Map && response['data'] is List
        ? List<dynamic>.from(response['data'] as List)
        : const <dynamic>[];
    final transactions = <_PaymentTransaction>[];
    for (final item in invoices.whereType<Map>()) {
      final invoice = Map<String, dynamic>.from(item);
      for (final entry
          in (invoice['transactions'] as List? ?? const []).whereType<Map>()) {
        final row = Map<String, dynamic>.from(entry);
        final isCredit =
            row['transactionType']?.toString().toUpperCase() == 'CREDIT';
        final received = row['isReceived'] == true ||
            row['isReceived']?.toString() == 'true';
        final date = _dateOf(row['transactionDate'] ?? invoice['invoiceDate']);
        transactions.add(_PaymentTransaction(
          id: 'credit-${invoice['id']}-${row['id'] ?? transactions.length}',
          date: date,
          title: isCredit ? 'Credit issued' : 'Credit settlement received',
          customer: _customerOf(invoice),
          reference: 'Credit ${invoice['id'] ?? ''}',
          amount: _number(row['amount']),
          direction: isCredit ? _Direction.outgoing : _Direction.incoming,
          status: isCredit && !received
              ? _TransactionStatus.pending
              : _TransactionStatus.completed,
          details: {
            'Type': isCredit ? 'Customer credit' : 'Settlement',
            if ((row['productName'] ?? '').toString().trim().isNotEmpty)
              'Product': row['productName'].toString(),
            if (row['quantity'] != null) 'Quantity': row['quantity'].toString(),
            if (row['price'] != null)
              'Unit price': _money(_number(row['price'])),
            if ((row['notes'] ?? '').toString().trim().isNotEmpty)
              'Notes': row['notes'].toString(),
          },
        ));
      }
    }
    return transactions.where((item) => _inDateRange(item.date)).toList();
  }

  List<dynamic> _rows(dynamic response) {
    if (response is List) return response;
    if (response is! Map) return const [];
    final data = response['data'];
    if (data is List) return data;
    if (data is Map) {
      for (final key in ['items', 'invoices', 'rows', 'data']) {
        if (data[key] is List) return data[key] as List;
      }
    }
    return response['items'] is List ? response['items'] as List : const [];
  }

  bool _inDateRange(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return (_fromDate == null ||
            !day.isBefore(
                DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) &&
        (_toDate == null ||
            !day.isAfter(
                DateTime(_toDate!.year, _toDate!.month, _toDate!.day)));
  }

  List<_PaymentTransaction> get _visible => _transactions.where((item) {
        if (_filter != _TransactionFilter.all && !item.matches(_filter)) {
          return false;
        }
        final needle = _query.toLowerCase();
        return needle.isEmpty ||
            '${item.title} ${item.customer} ${item.reference}'
                .toLowerCase()
                .contains(needle);
      }).toList();

  Map<DateTime, List<_PaymentTransaction>> get _grouped {
    final groups = <DateTime, List<_PaymentTransaction>>{};
    for (final item in _visible) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      (groups[day] ??= []).add(item);
    }
    return groups;
  }

  Future<void> _pickDate(bool from) async {
    final current = from ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate != null && _fromDate!.isAfter(picked)) _fromDate = picked;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible;
    final completedIn = visible
        .where((item) =>
            item.direction == _Direction.incoming &&
            item.status == _TransactionStatus.completed)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final outgoing = visible
        .where((item) => item.direction == _Direction.outgoing)
        .fold<double>(0, (sum, item) => sum + item.amount);
    return WorkspacePage(
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: Ui.pagePadding(context),
          children: [
            PageIntro(
              eyebrow: 'Read-only ledger',
              title: 'Payments',
              description:
                  'A single timeline of invoice receipts and customer credit activity.',
              action: IconButton.filledTonal(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh payments'),
            ),
            const SizedBox(height: 16),
            _Summary(
                incoming: completedIn,
                outgoing: outgoing,
                count: visible.length),
            const SizedBox(height: 16),
            SurfacePanel(
              child: Column(children: [
                TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search customer or invoice',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final filter in _TransactionFilter.values)
                    ChoiceChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter)),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(_fromDate == null
                          ? 'From date'
                          : DateFormat('dd MMM y').format(_fromDate!))),
                  OutlinedButton.icon(
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(_toDate == null
                          ? 'To date'
                          : DateFormat('dd MMM y').format(_toDate!))),
                  if (_fromDate != null || _toDate != null)
                    TextButton(
                        onPressed: () {
                          setState(() {
                            _fromDate = null;
                            _toDate = null;
                          });
                          _load();
                        },
                        child: const Text('Clear dates')),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()))
            else if (visible.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                      child: Text('No payment activity matches these filters.',
                          style: TextStyle(color: scheme.onSurfaceVariant))))
            else
              for (final group in _grouped.entries) ...[
                Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                    child: Text(_dayLabel(group.key),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: scheme.onSurfaceVariant))),
                ...group.value.map((item) => _PaymentTile(item: item)),
              ],
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(
      {required this.incoming, required this.outgoing, required this.count});
  final double incoming;
  final double outgoing;
  final int count;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cards = [
          _SummaryValue(
              label: 'Received',
              value: _money(incoming),
              icon: Icons.south_west_rounded,
              color: Colors.green),
          _SummaryValue(
              label: 'Credit issued',
              value: _money(outgoing),
              icon: Icons.north_east_rounded,
              color: Colors.orange),
          _SummaryValue(
              label: 'Entries',
              value: '$count',
              icon: Icons.receipt_long_outlined,
              color: Theme.of(context).colorScheme.primary),
        ];
        return box.maxWidth < 470
            ? Column(children: [
                for (final card in cards)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8), child: card)
              ])
            : Row(children: [
                for (final card in cards)
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: card))
              ]);
      });
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SurfacePanel(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        CircleAvatar(
            backgroundColor: color.withValues(alpha: .14),
            foregroundColor: color,
            child: Icon(icon)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700))
        ]))
      ]));
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.item});
  final _PaymentTransaction item;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outgoing = item.direction == _Direction.outgoing;
    final color = item.status == _TransactionStatus.pending
        ? scheme.error
        : outgoing
            ? Colors.orange.shade800
            : Colors.green.shade700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _showDetails(context),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: color.withValues(alpha: .14),
                  foregroundColor: color,
                  child: Icon(item.status == _TransactionStatus.pending
                      ? Icons.schedule_rounded
                      : outgoing
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item.customer.isEmpty ? item.title : item.customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('${item.title} · ${item.reference}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(DateFormat('h:mm a').format(item.date),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant))
                  ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${outgoing ? '-' : '+'}${_money(item.amount)}',
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(item.status.label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: color))
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment details',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 18),
                _DetailRow('Amount',
                    '${item.direction == _Direction.outgoing ? '-' : '+'}${_money(item.amount)}'),
                _DetailRow('Status', item.status.label),
                _DetailRow('Activity', item.title),
                _DetailRow('Customer',
                    item.customer.isEmpty ? 'Walk-in customer' : item.customer),
                _DetailRow('Reference', item.reference),
                _DetailRow(
                    'Date', DateFormat('dd MMMM y, h:mm a').format(item.date)),
                for (final detail in item.details.entries)
                  _DetailRow(detail.key, detail.value),
              ]),
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 122,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)))
      ]));
}

enum _Direction { incoming, outgoing }

enum _TransactionStatus {
  completed('Completed'),
  partial('Part paid'),
  pending('Pending');

  const _TransactionStatus(this.label);
  final String label;
}

enum _TransactionFilter {
  all('All'),
  incoming('Received'),
  outgoing('Credit issued'),
  pending('Pending');

  const _TransactionFilter(this.label);
  final String label;
}

class _PaymentTransaction {
  const _PaymentTransaction(
      {required this.id,
      required this.date,
      required this.title,
      required this.customer,
      required this.reference,
      required this.amount,
      required this.direction,
      required this.status,
      required this.details});
  final String id, title, customer, reference;
  final DateTime date;
  final double amount;
  final _Direction direction;
  final _TransactionStatus status;
  final Map<String, String> details;
  bool matches(_TransactionFilter filter) => switch (filter) {
        _TransactionFilter.all => true,
        _TransactionFilter.incoming => direction == _Direction.incoming,
        _TransactionFilter.outgoing => direction == _Direction.outgoing,
        _TransactionFilter.pending => status == _TransactionStatus.pending
      };
}

double _number(dynamic value) =>
    (value as num?)?.toDouble() ??
    double.tryParse(value?.toString() ?? '') ??
    0;
String _money(double value) => '₹${value.toStringAsFixed(2)}';
DateTime _dateOf(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
String _customerOf(Map<String, dynamic> row) {
  final name = (row['customerName'] ?? '').toString().trim();
  return name == 'NO_NAME' || name == 'Walk-in customer' ? '' : name;
}

String _dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (date == today) return 'Today';
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('EEEE, dd MMMM y').format(date);
}
