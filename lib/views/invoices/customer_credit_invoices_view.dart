import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';

class CustomerCreditInvoicesView extends StatefulWidget {
  const CustomerCreditInvoicesView({super.key});
  @override
  State<CustomerCreditInvoicesView> createState() =>
      _CustomerCreditInvoicesViewState();
}

class _CustomerCreditInvoicesViewState
    extends State<CustomerCreditInvoicesView> {
  bool _loading = true;
  List<dynamic> _invoices = const [];
  _CreditFilter _filter = _CreditFilter.pending;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService.get(ApiConfig.customerCreditInvoices,
          queryParameters: const {'pendingOnly': 'false'});
      if (!mounted) return;
      setState(() => _invoices = response is Map && response['data'] is List
          ? List<dynamic>.from(response['data'])
          : []);
    } catch (e) {
      _message('Could not load credit entries: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _openForm([Map<String, dynamic>? invoice]) async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreditForm(isNew: invoice == null),
    );
    if (data == null) return;
    try {
      if (invoice == null) {
        await ApiService.post(ApiConfig.customerCreditInvoices, data);
      } else {
        data.remove('customerName');
        data.remove('customerMobileNumber');
        data['amount'] = data.remove('borrowedAmount');
        data['transactionDate'] = data.remove('invoiceDate');
        await ApiService.post(
            '${ApiConfig.customerCreditInvoices}/${invoice['id']}/transactions',
            data);
      }
      if (!mounted) return;
      _message('Credit added.');
      _load();
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(title),
                content: Text(detail),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Received'))
                ],
              )) ??
      false;
  Future<void> _receiveAll(Map<String, dynamic> invoice) async {
    if (!await _confirm('Receive total credit?',
        'This settles the full outstanding balance of ₹${_money(invoice['outstandingBalance'])}.')) {
      return;
    }
    try {
      await ApiService.put(
          '${ApiConfig.customerCreditInvoices}/${invoice['id']}/received', {});
      if (mounted) {
        _message('Total credit received.');
        _load();
      }
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<void> _receiveOne(
      Map<String, dynamic> invoice, Map<String, dynamic> entry) async {
    if (!await _confirm('Receive this credit?',
        'This settles ₹${_money(entry['amount'])} for this entry only.')) {
      return;
    }
    try {
      await ApiService.put(
          '${ApiConfig.customerCreditInvoices}/${invoice['id']}/transactions/${entry['id']}/received',
          {});
      if (mounted) {
        _message('Credit entry received.');
        _load();
      }
    } catch (e) {
      _message(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _openForm,
            icon: const Icon(Icons.add),
            label: const Text('Add Credit')),
        body: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                    children: [
                      Text('Add Credit',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text('Track customer credit and every received entry.',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final filter in _CreditFilter.values)
                          ChoiceChip(
                              label: Text(filter.label),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter)),
                      ]),
                      const SizedBox(height: 16),
                      if (_filteredInvoices.isEmpty)
                        const Padding(
                            padding: EdgeInsets.only(top: 72),
                            child: Center(
                                child: Text('No credit invoices found.')))
                      else
                        ..._filteredInvoices.map((item) => _CreditCard(
                            invoice: Map<String, dynamic>.from(item as Map),
                            onAdd: _openForm,
                            onTotalReceived: _receiveAll,
                            onEntryReceived: _receiveOne)),
                    ],
                  )),
      );

  List<dynamic> get _filteredInvoices => _invoices.where((item) {
        final invoice = item as Map;
        final complete = invoice['isReceived'] == true ||
            invoice['isReceived']?.toString() == 'true';
        return switch (_filter) {
          _CreditFilter.pending => !complete,
          _CreditFilter.completed => complete,
          _CreditFilter.all => true,
        };
      }).toList();
}

enum _CreditFilter {
  pending('Pending'),
  completed('Completed'),
  all('All');

  const _CreditFilter(this.label);
  final String label;
}

class _CreditCard extends StatelessWidget {
  const _CreditCard(
      {required this.invoice,
      required this.onAdd,
      required this.onTotalReceived,
      required this.onEntryReceived});
  final Map<String, dynamic> invoice;
  final ValueChanged<Map<String, dynamic>?> onAdd;
  final ValueChanged<Map<String, dynamic>> onTotalReceived;
  final void Function(Map<String, dynamic>, Map<String, dynamic>)
      onEntryReceived;
  @override
  Widget build(BuildContext context) {
    final entries = (invoice['transactions'] as List? ?? const [])
        .where((item) => item is Map && item['transactionType'] == 'CREDIT')
        .toList();
    final completed = _received(invoice);
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: CircleAvatar(child: Text(_initial(invoice['customerName']))),
          title: Text('${invoice['customerName'] ?? ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${invoice['customerMobileNumber'] ?? ''} • ${_formatDate(invoice['invoiceDate'])}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 88),
              child: Text(
                  completed
                      ? 'Completed'
                      : '₹${_money(invoice['outstandingBalance'])}',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    completed
                        ? 'All credit entries received'
                        : 'Current total due: ₹${_money(invoice['outstandingBalance'])}',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(height: 8),
            ...entries.map((item) {
              final entry = Map<String, dynamic>.from(item as Map);
              return _EntryTile(
                  entry: entry,
                  onReceived:
                      entry['transactionType'] == 'CREDIT' && !_received(entry)
                          ? () => onEntryReceived(invoice, entry)
                          : null);
            }),
            if (!completed) const Divider(height: 24),
            if (!completed)
              LayoutBuilder(builder: (context, box) {
                final actions = [
                  OutlinedButton.icon(
                      onPressed: () => onAdd(invoice),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Credit')),
                  FilledButton.icon(
                      onPressed: () => onTotalReceived(invoice),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Receive Total'))
                ];
                return box.maxWidth < 330
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: actions)
                    : Wrap(spacing: 8, runSpacing: 8, children: actions);
              }),
          ],
        ));
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, this.onReceived});
  final Map<String, dynamic> entry;
  final VoidCallback? onReceived;
  @override
  Widget build(BuildContext context) {
    final settled = _received(entry);
    final credit = entry['transactionType'] == 'CREDIT';
    final product = entry['productName']?.toString().trim();
    return Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
            color: settled
                ? Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: .45)
                : null,
            borderRadius: BorderRadius.circular(12)),
        child: InkWell(
            onTap: () => _showDetails(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(settled || !credit
                        ? Icons.check_circle_outline
                        : Icons.add_circle_outline),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              product == null || product.isEmpty
                                  ? (credit ? 'Credit entry' : 'Settlement')
                                  : product,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                              '${_formatDate(entry['transactionDate'])} • ₹${_money(entry['amount'])}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)
                        ])),
                    if (settled)
                      const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check, size: 18))
                  ]),
                  if (onReceived != null)
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                            onPressed: onReceived,
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Received'))),
                ]))));
  }

  void _showDetails(BuildContext context) {
    final credit = entry['transactionType'] == 'CREDIT';
    final settled = _received(entry);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaction details',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _detailRow('Date', _formatDate(entry['transactionDate'])),
              _detailRow('Type', credit ? 'Credit' : 'Settlement'),
              _detailRow('Amount', '₹${_money(entry['amount'])}'),
              if (credit)
                _detailRow('Status', settled ? 'Received' : 'Pending'),
              if (entry['productName']?.toString().trim().isNotEmpty == true)
                _detailRow('Product', entry['productName'].toString()),
              if (entry['quantity'] != null)
                _detailRow('Quantity', entry['quantity'].toString()),
              if (entry['price'] != null)
                _detailRow('Unit price', '₹${_money(entry['price'])}'),
              if (entry['notes']?.toString().trim().isNotEmpty == true)
                _detailRow('Notes', entry['notes'].toString()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(label)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _CreditForm extends StatefulWidget {
  const _CreditForm({required this.isNew});
  final bool isNew;
  @override
  State<_CreditForm> createState() => _CreditFormState();
}

class _CreditFormState extends State<_CreditForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final List<_Item> _items = [];
  DateTime _date = DateTime.now();
  @override
  void dispose() {
    for (final c in [_name, _mobile, _amount, _notes]) {
      c.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(0, (sum, item) => sum + item.total);
    return SafeArea(
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 20),
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Add Credit',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          if (widget.isNew) ...[
                            _field(_name, 'Customer name', required: true),
                            _field(_mobile, 'Mobile number',
                                required: true, keyboard: TextInputType.phone)
                          ],
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Date'),
                              subtitle: Text(_formatDate(_date)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final picked = await showDatePicker(
                                    context: context,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    initialDate: _date);
                                if (picked != null) {
                                  setState(() => _date = picked);
                                }
                              }),
                          Text('Products',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          const Text(
                              'Add each product below. Every product can be marked received separately.'),
                          const SizedBox(height: 8),
                          ..._items.asMap().entries.map((pair) => _ItemFields(
                              key: ValueKey(pair.value),
                              item: pair.value,
                              index: pair.key,
                              onChanged: () => setState(() {}),
                              onRemove: () => setState(() {
                                    final item = _items.removeAt(pair.key);
                                    item.dispose();
                                  }))),
                          OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _items.add(_Item())),
                              icon: const Icon(Icons.add),
                              label: const Text('Add product')),
                          const SizedBox(height: 12),
                          if (_items.isEmpty)
                            _field(_amount, 'Credit amount',
                                required: true,
                                keyboard: const TextInputType.numberWithOptions(
                                    decimal: true))
                          else
                            _Total(total: total),
                          _field(_notes, 'Notes (optional)', maxLines: 2),
                          FilledButton(
                              onPressed: _submit,
                              child: const Text('Save Credit')),
                        ])))));
  }

  Widget _field(TextEditingController c, String label,
          {bool required = false, TextInputType? keyboard, int maxLines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
              controller: c,
              keyboardType: keyboard,
              maxLines: maxLines,
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder()),
              validator: required
                  ? (v) => v == null || v.trim().isEmpty
                      ? '$label is required'
                      : null
                  : null));
  void _submit() {
    if (!_form.currentState!.validate()) return;
    final itemTotal = _items.fold<double>(0, (sum, item) => sum + item.total);
    final manual = double.tryParse(_amount.text.trim());
    if ((_items.isNotEmpty &&
            (!_items.every((i) => i.valid) || itemTotal <= 0)) ||
        (_items.isEmpty && (manual == null || manual <= 0))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter valid product details or a credit amount.')));
      return;
    }
    Navigator.pop(context, {
      'customerName': _name.text.trim(),
      'customerMobileNumber': _mobile.text.trim(),
      'borrowedAmount': _items.isEmpty ? manual : itemTotal,
      'invoiceDate': _date.toIso8601String(),
      if (_items.isNotEmpty)
        'items': _items
            .map((i) => {
                  'productName': i.name.text.trim(),
                  'quantity': i.quantityValue,
                  'price': i.priceValue
                })
            .toList(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim()
    });
  }
}

class _ItemFields extends StatelessWidget {
  const _ItemFields(
      {super.key,
      required this.item,
      required this.index,
      required this.onChanged,
      required this.onRemove});
  final _Item item;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('Product ${index + 1}')),
              IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove product')
            ]),
            TextFormField(
                controller: item.name,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                    labelText: 'Product name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            LayoutBuilder(
                builder: (context, box) => box.maxWidth < 300
                    ? Column(children: _numbers(false))
                    : Row(children: _numbers(true))),
            const SizedBox(height: 8),
            Align(
                alignment: Alignment.centerRight,
                child: Text('Line total: ₹${item.total.toStringAsFixed(2)}'))
          ])));
  List<Widget> _numbers(bool row) {
    final q = TextFormField(
        controller: item.quantity,
        onChanged: (_) => onChanged(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
            labelText: 'Quantity', border: OutlineInputBorder()));
    final p = TextFormField(
        controller: item.price,
        onChanged: (_) => onChanged(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
            labelText: 'Unit price', border: OutlineInputBorder()));
    return row
        ? [Expanded(child: q), const SizedBox(width: 10), Expanded(child: p)]
        : [q, const SizedBox(height: 10), p];
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.total});
  final double total;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Expanded(child: Text('Total credit amount')),
        Text('₹${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold))
      ]));
}

class _Item {
  final name = TextEditingController();
  final quantity = TextEditingController();
  final price = TextEditingController();
  double get quantityValue => double.tryParse(quantity.text.trim()) ?? 0;
  double get priceValue => double.tryParse(price.text.trim()) ?? 0;
  double get total => quantityValue * priceValue;
  bool get valid =>
      name.text.trim().isNotEmpty && quantityValue > 0 && priceValue > 0;
  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
  }
}

bool _received(Map<String, dynamic> entry) =>
    entry['isReceived'] == true || entry['isReceived']?.toString() == 'true';
String _money(dynamic value) => ((value as num?)?.toDouble() ??
        double.tryParse(value?.toString() ?? '') ??
        0)
    .toStringAsFixed(2);
String _formatDate(dynamic value) {
  final text = value?.toString() ?? '';
  return text.length >= 10 ? text.substring(0, 10) : text;
}

String _initial(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '?' : text.substring(0, 1).toUpperCase();
}
