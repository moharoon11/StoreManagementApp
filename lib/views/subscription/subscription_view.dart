import 'dart:math';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import 'package:provider/provider.dart';

class SubscriptionView extends StatefulWidget {
  const SubscriptionView({super.key});
  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView> {
  late final Razorpay _razorpay;
  Map<String, dynamic>? _plan;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET,
          (_) => _setError('External wallet payment was not completed.'));
    _loadPlan();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadPlan() async {
    try {
      final response = await ApiService.get(ApiConfig.subscriptionOptions);
      final data = response is Map ? response['data'] : null;
      if (data is Map) _plan = Map<String, dynamic>.from(data);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _begin(String period, {bool trial = false}) async {
    if (_working) return;
    final appProvider = context.read<AppProvider>();
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final response = await ApiService.post(ApiConfig.subscriptionStart, {
        'billingPeriod': trial ? 'trial' : period,
        'startTrial': trial,
        'idempotencyKey': _newIdempotencyKey(),
      });
      final data = response is Map ? response['data'] : null;
      if (data is! Map) {
        throw Exception(
            'The subscription server returned an invalid response.');
      }
      if (data['status'] == 'trialing') {
        await appProvider.refreshSubscriptionStatus();
        return;
      }
      final orderId = data['orderId']?.toString();
      final key = data['keyId']?.toString();
      final paymentId = data['paymentId']?.toString();
      if ([orderId, key, paymentId].any((v) => v == null || v.isEmpty)) {
        throw Exception('The payment order is incomplete.');
      }
      _pendingPaymentId = paymentId;
      _pendingOrderId = orderId;
      _razorpay.open({
        'key': key,
        'amount': data['amountMinor'],
        'currency': data['currency'],
        'order_id': orderId,
        'name': 'BillMate Subscription',
        'description': trial ? 'Free trial' : 'Store management subscription',
        'notes': {'platformPaymentId': paymentId},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      if (mounted) setState(() => _working = false);
    }
  }

  String? _pendingPaymentId;
  String? _pendingOrderId;

  Future<void> _onPaymentSuccess(PaymentSuccessResponse payment) async {
    final appProvider = context.read<AppProvider>();
    try {
      final response = await ApiService.post(ApiConfig.subscriptionVerify, {
        'paymentId': _pendingPaymentId,
        'orderId': _pendingOrderId,
        'razorpayPaymentId': payment.paymentId,
        'signature': payment.signature,
      });
      if (response is! Map || response['success'] != true) {
        throw Exception('Server could not confirm the captured payment.');
      }
      await appProvider.refreshSubscriptionStatus();
    } catch (e) {
      _setError(
          'Payment was submitted, but server confirmation is pending. ${e.toString().replaceFirst('Exception: ', '')}');
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _onPaymentError(PaymentFailureResponse response) async {
    final paymentId = _pendingPaymentId;
    final orderId = _pendingOrderId;
    if (paymentId != null && orderId != null) {
      try {
        await ApiService.post(ApiConfig.subscriptionFailure, {
          'paymentId': paymentId,
          'orderId': orderId,
        });
      } catch (_) {
        // The platform expires abandoned pending orders after 30 minutes.
      }
    }
    _setError(response.message?.trim().isNotEmpty == true
        ? response.message!
        : 'Payment was not completed.');
    if (mounted) setState(() => _working = false);
  }

  void _setError(String message) {
    if (mounted) setState(() => _error = message);
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    return 'flutter-${DateTime.now().toUtc().microsecondsSinceEpoch}-${List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join()}';
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan ?? const <String, dynamic>{};
    final currency = plan['currency']?.toString() ?? 'INR';
    final trialDays = (plan['trial_days'] as num?)?.toInt() ?? 0;
    final options = <(String, String, String)>[
      ('three_month', '3 months', 'three_month_amount_minor'),
      ('six_month', '6 months', 'six_month_amount_minor'),
      ('one_year', '1 year', 'yearly_amount_minor'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your subscription')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    const Icon(Icons.storefront, size: 54),
                    const SizedBox(height: 12),
                    Text('Continue with BillMate',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text(
                        'Choose a term to unlock store management. Paid terms are prepaid fixed periods and do not renew automatically.',
                        textAlign: TextAlign.center),
                    if (trialDays > 0) ...[
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                          onPressed: _working
                              ? null
                              : () => _begin('trial', trial: true),
                          icon: const Icon(Icons.card_giftcard),
                          label: Text('Start $trialDays-day free trial')),
                    ],
                    const SizedBox(height: 16),
                    ...options.map((option) {
                      final minor = (plan[option.$3] as num?)?.toInt() ?? 0;
                      if (minor <= 0) return const SizedBox.shrink();
                      return Card(
                          child: ListTile(
                              title: Text(option.$2),
                              subtitle: Text(
                                  '$currency ${(minor / 100).toStringAsFixed(2)}'),
                              trailing: FilledButton(
                                  onPressed:
                                      _working ? null : () => _begin(option.$1),
                                  child: const Text('Pay securely'))));
                    }),
                    if (_working)
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator())),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                              textAlign: TextAlign.center)),
                  ]))),
    );
  }
}
