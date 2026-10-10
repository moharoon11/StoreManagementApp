import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/invoice_pdf_service.dart';
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
  _RangeScope _scope = _RangeScope.today;
  DateTime? _fromDate;
  DateTime? _toDate;
  Map<String, dynamic> _store = const {};
  List<_PaymentTransaction> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _applyScope(_RangeScope.today, reload: false);
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
      final storeRequest = _loadStore();
      final results = await Future.wait<_PaymentTransactionList>([
        _safeLoad(_loadInvoices()),
        _safeLoad(_loadCredit()),
      ]);
      final invoices = results[0];
      final credit = results[1];
      final store = await storeRequest;
      if (mounted) {
        setState(() {
          _store = store;
          _transactions = [...invoices, ...credit]
            ..sort((a, b) => b.date.compareTo(a.date));
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>> _loadStore() async {
    try {
      final response = await ApiService.get(ApiConfig.storeProfile);
      final data = response is Map ? response['data'] : null;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } catch (_) {
      return const {};
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

  Future<void> _pickCustomRange() async {
    final start = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'START DATE',
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate:
          _toDate == null || _toDate!.isBefore(start) ? start : _toDate!,
      firstDate: start,
      lastDate: DateTime.now(),
      helpText: 'END DATE',
    );
    if (end == null || !mounted) return;
    setState(() {
      _scope = _RangeScope.custom;
      _fromDate = start;
      _toDate = end;
    });
    _load();
  }

  void _applyScope(_RangeScope scope, {bool reload = true}) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    setState(() {
      _scope = scope;
      switch (scope) {
        case _RangeScope.today:
          _fromDate = startOfToday;
          _toDate = startOfToday;
        case _RangeScope.week:
          _fromDate =
              startOfToday.subtract(Duration(days: startOfToday.weekday - 1));
          _toDate = startOfToday;
        case _RangeScope.month:
          _fromDate = DateTime(today.year, today.month, 1);
          _toDate = startOfToday;
        case _RangeScope.custom:
          break;
      }
    });
    if (reload) _load();
  }

  Future<void> _export(_ExportAction action) async {
    if (action == _ExportAction.selectRange) {
      await _pickCustomRange();
      return;
    }
    final bytes =
        await _PaymentPdf.createHistory(_visible, _rangeLabel, _store);
    final filename =
        'Payment_history_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    switch (action) {
      case _ExportAction.selectRange:
        return;
      case _ExportAction.download:
        await InvoicePdfService.save(bytes, filename);
      case _ExportAction.share:
        await Printing.sharePdf(bytes: bytes, filename: filename);
      case _ExportAction.print:
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: filename);
    }
  }

  String get _rangeLabel => _scope == _RangeScope.custom
      ? '${_fromDate == null ? 'Start' : DateFormat('dd MMM y').format(_fromDate!)} – ${_toDate == null ? 'Now' : DateFormat('dd MMM y').format(_toDate!)}'
      : _scope.label;

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
            Row(children: [
              Expanded(
                  child: Text('Payments',
                      style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh'),
              PopupMenuButton<_ExportAction>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: _export,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: _ExportAction.selectRange,
                      child: _ExportMenuItem(
                          icon: Icons.date_range_outlined,
                          label: 'Choose date range',
                          color: Colors.deepPurple)),
                  PopupMenuDivider(),
                  PopupMenuItem(
                      value: _ExportAction.download,
                      child: _ExportMenuItem(
                          icon: Icons.download_outlined,
                          label: 'Download PDF',
                          color: Colors.blue)),
                  PopupMenuItem(
                      value: _ExportAction.share,
                      child: _ExportMenuItem(
                          icon: Icons.share_outlined,
                          label: 'Share PDF',
                          color: Colors.teal)),
                  PopupMenuItem(
                      value: _ExportAction.print,
                      child: _ExportMenuItem(
                          icon: Icons.print_outlined,
                          label: 'Print PDF',
                          color: Colors.orange)),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            _Summary(incoming: completedIn, outgoing: outgoing),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search customer or invoice',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final scope in _RangeScope.values)
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(scope.label),
                            selected: _scope == scope,
                            onSelected: (_) => scope == _RangeScope.custom
                                ? _pickCustomRange()
                                : _applyScope(scope))),
                  const SizedBox(width: 4),
                  for (final filter in _TransactionFilter.values
                      .where((filter) => filter != _TransactionFilter.all))
                    Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                            label: Text(filter.label),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter =
                                _filter == filter
                                    ? _TransactionFilter.all
                                    : filter))),
                ])),
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
                ...group.value
                    .map((item) => _PaymentTile(item: item, store: _store)),
              ],
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.incoming, required this.outgoing});
  final double incoming;
  final double outgoing;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _SummaryValue(
                label: 'Received',
                value: _money(incoming),
                color: Colors.green)),
        const SizedBox(width: 10),
        Expanded(
            child: _SummaryValue(
                label: 'Credit issued',
                value: _money(outgoing),
                color: Colors.orange)),
      ]);
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      ]));
}

class _ExportMenuItem extends StatelessWidget {
  const _ExportMenuItem({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(label),
      ]);
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.item, required this.store});
  final _PaymentTransaction item;
  final Map<String, dynamic> store;
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
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _PaymentDetailPage(item: item, store: store))),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: color.withValues(alpha: .16),
                  foregroundColor: color,
                  child: Text(
                      _initials(
                          item.customer.isEmpty ? item.title : item.customer),
                      style: const TextStyle(fontWeight: FontWeight.w800))),
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

class _PaymentDetailPage extends StatelessWidget {
  const _PaymentDetailPage({required this.item, required this.store});
  final _PaymentTransaction item;
  final Map<String, dynamic> store;

  Future<void> _usePdf(BuildContext context, _ExportAction action) async {
    final bytes = await _PaymentPdf.createTransaction(item, store);
    final filename =
        'Payment_${item.reference.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';
    switch (action) {
      case _ExportAction.selectRange:
        return;
      case _ExportAction.download:
        await InvoicePdfService.save(bytes, filename);
      case _ExportAction.share:
        await Printing.sharePdf(bytes: bytes, filename: filename);
      case _ExportAction.print:
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: filename);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outgoing = item.direction == _Direction.outgoing;
    final color = outgoing ? Colors.orange.shade800 : Colors.green.shade700;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment details')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
              child: CircleAvatar(
                  radius: 30,
                  backgroundColor: color.withValues(alpha: .15),
                  foregroundColor: color,
                  child: Text(
                      _initials(
                          item.customer.isEmpty ? item.title : item.customer),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)))),
          const SizedBox(height: 14),
          Center(
              child: Text('${outgoing ? '-' : '+'}${_money(item.amount)}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w800))),
          const SizedBox(height: 4),
          Center(
              child: Text(item.status.label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700))),
          const SizedBox(height: 28),
          _DetailRow('Activity', item.title),
          _DetailRow('Customer',
              item.customer.isEmpty ? 'Walk-in customer' : item.customer),
          _DetailRow('Reference', item.reference),
          _DetailRow('Date', DateFormat('dd MMMM y, h:mm a').format(item.date)),
          for (final detail in item.details.entries)
            _DetailRow(detail.key, detail.value),
          const SizedBox(height: 18),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                    onPressed: () => _usePdf(context, _ExportAction.download),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download')),
                OutlinedButton.icon(
                    onPressed: () => _usePdf(context, _ExportAction.share),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share')),
                FilledButton.icon(
                    onPressed: () => _usePdf(context, _ExportAction.print),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print')),
              ]),
        ]),
      ),
    );
  }
}

class _PaymentPdf {
  static Future<Uint8List> createTransaction(
          _PaymentTransaction item, Map<String, dynamic> store) =>
      _document(
        title: 'PAYMENT RECEIPT',
        subtitle: item.reference,
        store: store,
        rows: [
          ['Activity', item.title],
          [
            'Customer',
            item.customer.isEmpty ? 'Walk-in customer' : item.customer
          ],
          ['Status', item.status.label],
          ['Date', DateFormat('dd MMM y, h:mm a').format(item.date)],
          ...item.details.entries.map((entry) => [entry.key, entry.value]),
          ['Amount', _pdfAmount(item.amount, item.direction)],
        ],
      );

  static Future<Uint8List> createHistory(List<_PaymentTransaction> items,
          String period, Map<String, dynamic> store) =>
      _document(
        title: 'PAYMENT HISTORY',
        subtitle: period,
        store: store,
        rows: items
            .map((item) => [
                  DateFormat('dd MMM y').format(item.date),
                  item.customer.isEmpty ? item.title : item.customer,
                  item.reference,
                  _pdfAmount(item.amount, item.direction),
                ])
            .toList(),
        headers: const ['Date', 'Customer', 'Reference', 'Amount'],
      );

  static Future<Uint8List> _document(
      {required String title,
      required String subtitle,
      required Map<String, dynamic> store,
      required List<List<String>> rows,
      List<String>? headers}) async {
    final fonts = await PdfDocumentFonts.load();
    final document = pw.Document(theme: fonts.theme);
    final storeName = _storeText(store['storeName'], 'STORE MANAGEMENT');
    final owner = _storeText(store['ownerName'], '');
    final address = _storeText(store['address'], '');
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        pw.Text(storeName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        if (owner.isNotEmpty) pw.Text('Owner: $owner'),
        if (address.isNotEmpty) pw.Text(address),
        pw.SizedBox(height: 14),
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800)),
        pw.SizedBox(height: 5),
        pw.Text(subtitle),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
            headers: headers ?? const ['Field', 'Value'],
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellPadding: const pw.EdgeInsets.all(7)),
      ],
    ));
    return document.save();
  }
}

enum _Direction { incoming, outgoing }

enum _RangeScope {
  today('Today'),
  week('This week'),
  month('This month'),
  custom('Custom');

  const _RangeScope(this.label);
  final String label;
}

enum _ExportAction { selectRange, download, share, print }

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
String _pdfAmount(double value, _Direction direction) =>
    '${direction == _Direction.outgoing ? '-' : '+'} INR ${value.toStringAsFixed(2)}';
String _storeText(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? fallback : text;
}

DateTime _dateOf(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
String _customerOf(Map<String, dynamic> row) {
  final name = (row['customerName'] ?? '').toString().trim();
  return name == 'NO_NAME' || name == 'Walk-in customer' ? '' : name;
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}

String _dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (date == today) return 'Today';
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('EEEE, dd MMMM y').format(date);
}
