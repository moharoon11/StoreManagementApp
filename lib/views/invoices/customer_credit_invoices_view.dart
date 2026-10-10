import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';

class CustomerCreditInvoicesView extends StatefulWidget {
  const CustomerCreditInvoicesView({super.key});

  @override
  State<CustomerCreditInvoicesView> createState() =>
      _CustomerCreditInvoicesViewState();
}

class _CustomerCreditInvoicesViewState extends State<CustomerCreditInvoicesView> {
  bool _loading = true;
  List<dynamic> _invoices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService.get(
        ApiConfig.customerCreditInvoices,
        queryParameters: const {'pendingOnly': 'true'},
      );
      if (!mounted) return;
      final data = response is Map ? response['data'] : null;
      setState(() => _invoices = data is List ? List<dynamic>.from(data) : []);
    } catch (error) {
      _message('Could not load customer credit invoices: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _create() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreditForm(title: 'New customer credit invoice'),
    );
    if (result == null) return;
    try {
      await ApiService.post(ApiConfig.customerCreditInvoices, result);
      if (!mounted) return;
      _message('Customer credit invoice created.');
      _load();
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _addTransaction(Map<String, dynamic> invoice) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreditForm(title: 'Add credit transaction'),
    );
    if (result == null) return;
    result.remove('customerName');
    result.remove('customerMobileNumber');
    result['amount'] = result.remove('borrowedAmount');
    try {
      await ApiService.post(
        '${ApiConfig.customerCreditInvoices}/${invoice['id']}/transactions',
        result,
      );
      if (!mounted) return;
      _message('Transaction added.');
      _load();
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _markReceived(Map<String, dynamic> invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as received?'),
        content: Text('This will settle ₹${_money(invoice['outstandingBalance'])} and remove this invoice from pending.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Received')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.put('${ApiConfig.customerCreditInvoices}/${invoice['id']}/received', {});
      if (!mounted) return;
      _message('Invoice marked as received.');
      _load();
    } catch (error) {
      _message(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New credit'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Text('Customer credit', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Pending customer balances', style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 18),
                  if (_invoices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 72),
                      child: Center(child: Text('No pending customer credit invoices.')),
                    )
                  else
                    ..._invoices.map((item) => _CreditInvoiceCard(
                          invoice: Map<String, dynamic>.from(item as Map),
                          onAdd: _addTransaction,
                          onReceived: _markReceived,
                        )),
                ],
              ),
      ),
    );
  }
}

class _CreditInvoiceCard extends StatelessWidget {
  const _CreditInvoiceCard({required this.invoice, required this.onAdd, required this.onReceived});
  final Map<String, dynamic> invoice;
  final ValueChanged<Map<String, dynamic>> onAdd;
  final ValueChanged<Map<String, dynamic>> onReceived;

  @override
  Widget build(BuildContext context) {
    final transactions = (invoice['transactions'] as List? ?? const []);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(_initial(invoice['customerName']))),
        title: Text((invoice['customerName'] ?? '').toString()),
        subtitle: Text('${invoice['customerMobileNumber'] ?? ''} • ${_formatDate(invoice['invoiceDate'])}'),
        trailing: Text('₹${_money(invoice['outstandingBalance'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text('Outstanding balance: ₹${_money(invoice['outstandingBalance'])}', style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(height: 8),
          ...transactions.map((item) {
            final transaction = Map<String, dynamic>.from(item as Map);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(transaction['transactionType'] == 'SETTLEMENT' ? Icons.check_circle_outline : Icons.add_circle_outline),
              title: Text('₹${_money(transaction['amount'])}'),
              subtitle: Text('${_formatDate(transaction['transactionDate'])}${transaction['productName'] != null ? ' • ${transaction['productName']}' : ''}'),
              onTap: () => _transactionDetails(context, transaction),
            );
          }),
          const Divider(),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: () => onAdd(invoice), icon: const Icon(Icons.add), label: const Text('Add transaction')),
            FilledButton.icon(onPressed: () => onReceived(invoice), icon: const Icon(Icons.check), label: const Text('Received')),
          ]),
        ],
      ),
    );
  }

  void _transactionDetails(BuildContext context, Map<String, dynamic> transaction) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Transaction details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _row('Date', _formatDate(transaction['transactionDate'])),
          _row('Amount', '₹${_money(transaction['amount'])}'),
          _row('Type', (transaction['transactionType'] ?? '').toString()),
          if (transaction['productName'] != null) _row('Product', transaction['productName'].toString()),
          if (transaction['quantity'] != null) _row('Quantity', transaction['quantity'].toString()),
          if (transaction['price'] != null) _row('Price', '₹${_money(transaction['price'])}'),
          if (transaction['notes'] != null) _row('Notes', transaction['notes'].toString()),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [SizedBox(width: 88, child: Text(label)), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)))]));
}

class _CreditForm extends StatefulWidget {
  const _CreditForm({required this.title});
  final String title;
  @override State<_CreditForm> createState() => _CreditFormState();
}

class _CreditFormState extends State<_CreditForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(); final _mobile = TextEditingController(); final _amount = TextEditingController();
  final _product = TextEditingController(); final _quantity = TextEditingController(); final _price = TextEditingController(); final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  bool get _isNew => widget.title.startsWith('New');
  @override void dispose() { for (final c in [_name,_mobile,_amount,_product,_quantity,_price,_notes]) { c.dispose(); } super.dispose(); }
  @override Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
    child: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
      if (_isNew) ...[_field(_name, 'Customer name', required: true), _field(_mobile, 'Mobile number', required: true, keyboard: TextInputType.phone)],
      _field(_amount, _isNew ? 'Borrowed amount' : 'Additional credit amount', required: true, keyboard: const TextInputType.numberWithOptions(decimal: true)),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text('Date'), subtitle: Text(_formatDate(_date)), trailing: const Icon(Icons.calendar_today), onTap: () async { final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: _date); if (picked != null) setState(() => _date = picked); }),
      const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 8), child: Text('Optional product'))),
      _field(_product, 'Product name'), _field(_quantity, 'Quantity', keyboard: const TextInputType.numberWithOptions(decimal: true)), _field(_price, 'Price', keyboard: const TextInputType.numberWithOptions(decimal: true)), _field(_notes, 'Notes'),
      const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Save'))),
    ]))),
  );
  Widget _field(TextEditingController controller, String label, {bool required = false, TextInputType? keyboard}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextFormField(controller: controller, keyboardType: keyboard, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), validator: required ? (value) => value == null || value.trim().isEmpty ? '$label is required' : null : null));
  void _submit() { if (!_form.currentState!.validate()) return; final amount = num.tryParse(_amount.text); final productComplete = [_product.text,_quantity.text,_price.text].every((v) => v.trim().isNotEmpty); final productEmpty = [_product.text,_quantity.text,_price.text].every((v) => v.trim().isEmpty); final quantity = num.tryParse(_quantity.text); final price = num.tryParse(_price.text); if (amount == null || amount <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount greater than zero.'))); return; } if (!productComplete && !productEmpty || productComplete && (quantity == null || quantity <= 0 || price == null || price <= 0)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete all optional product fields with positive values or leave them blank.'))); return; } Navigator.pop(context, {'customerName': _name.text.trim(), 'customerMobileNumber': _mobile.text.trim(), 'borrowedAmount': amount, 'invoiceDate': _date.toIso8601String(), 'transactionDate': _date.toIso8601String(), if (productComplete) ...{'productName': _product.text.trim(), 'quantity': quantity, 'price': price}, if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim()}); }
}

String _money(dynamic value) => ((value as num?)?.toDouble() ?? 0).toStringAsFixed(2);
String _formatDate(dynamic value) { final text = value?.toString() ?? ''; return text.length >= 10 ? text.substring(0, 10) : text; }
String _initial(dynamic value) { final name = value?.toString().trim() ?? ''; return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(); }
