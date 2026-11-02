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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await ApiService.get(ApiConfig.subscriptionOptions);
      final data = response is Map ? response['data'] : null;
      if (data is Map) {
        _plan = Map<String, dynamic>.from(data);
      } else {
        throw Exception('Plans are unavailable right now. Please try again.');
      }
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

  String _price(int minor, String currency) {
    final amount = minor / 100;
    final formatted = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return currency.toUpperCase() == 'INR'
        ? '₹$formatted'
        : '$currency $formatted';
  }

  Widget _benefit(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9FF0D4)),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _planCard({
    required String period,
    required String title,
    required int months,
    required int minor,
    required String currency,
    String? badge,
  }) {
    final featured = badge == 'Most popular';
    final accent = featured ? const Color(0xFF0F766E) : const Color(0xFF233C5B);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: featured ? const Color(0xFFF0FAF6) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: featured ? const Color(0xFF41B896) : const Color(0xFFDCE6E9),
          width: featured ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183B4A).withValues(alpha: .06),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  featured
                      ? Icons.auto_awesome_rounded
                      : Icons.calendar_month_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF183B4A),
                        )),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(_price(minor, currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF102F3D),
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 3),
          Text('About ${_price((minor / months).round(), currency)} per month',
              style: const TextStyle(color: Color(0xFF55727B), fontSize: 13)),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 17, color: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text('Full access for $title · one payment',
                    style: const TextStyle(
                        color: Color(0xFF415D66), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _working ? null : () => _begin(period),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Choose this plan'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan ?? const <String, dynamic>{};
    final currency = plan['currency']?.toString() ?? 'INR';
    final trialDays = (plan['trial_days'] as num?)?.toInt() ?? 0;
    final options = <(String, String, int, String, String?)>[
      ('three_month', '3 months', 3, 'three_month_amount_minor', null),
      ('six_month', '6 months', 6, 'six_month_amount_minor', 'Most popular'),
      ('one_year', '1 year', 12, 'yearly_amount_minor', 'Longest term'),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F7),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF123E49), Color(0xFF0F766E)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.storefront_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 7),
                                  Text('BILLMATE',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 25),
                            Text('Make every sale\ncount.',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      height: 1.08,
                                    )),
                            const SizedBox(height: 10),
                            const Text(
                              'One simple workspace to sell, stay on top of stock, and understand your business.',
                              style: TextStyle(
                                  color: Color(0xFFD6F2EA),
                                  fontSize: 14,
                                  height: 1.5),
                            ),
                            const SizedBox(height: 21),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                _benefit(Icons.point_of_sale_rounded,
                                    'Fast billing'),
                                _benefit(
                                    Icons.inventory_2_rounded, 'Stock control'),
                                _benefit(
                                    Icons.insights_rounded, 'Clear insights'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (trialDays > 0) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5E7),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFF7D7A7)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.card_giftcard_rounded,
                                  color: Color(0xFFC66B12), size: 26),
                              const SizedBox(height: 7),
                              Text('Try BillMate for $trialDays days',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              const Text(
                                  'Explore the workspace before choosing a plan.',
                                  style: TextStyle(color: Color(0xFF735C42))),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => _begin('trial', trial: true),
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: Text('Start $trialDays-day free trial'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text('Choose your pace',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF183B4A),
                                fontWeight: FontWeight.w800,
                              )),
                      const SizedBox(height: 5),
                      const Text(
                        'Every plan includes the same tools. Pay once for the term you choose; no automatic renewal.',
                        style: TextStyle(color: Color(0xFF55727B), height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      for (final option in options)
                        if ((plan[option.$4] as num?) != null &&
                            (plan[option.$4] as num) > 0)
                          _planCard(
                            period: option.$1,
                            title: option.$2,
                            months: option.$3,
                            minor: (plan[option.$4] as num).toInt(),
                            currency: currency,
                            badge: option.$5,
                          ),
                      if (_plan == null ||
                          options.every((option) =>
                              (plan[option.$4] as num?) == null ||
                              (plan[option.$4] as num) <= 0))
                        OutlinedButton.icon(
                          onPressed: _loadPlan,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Plans unavailable · Try again'),
                        ),
                      if (_working)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                              textAlign: TextAlign.center),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
