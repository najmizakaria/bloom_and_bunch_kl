import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/order_service.dart';
import '../../../core/widgets/page_navigation.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/utils/malaysia_time.dart';
import 'order_tracking_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.orderId,
    this.service,
    this.open,
    this.orderBuilder,
  }) : paymentId = null;
  const PaymentScreen.fromReturn({
    super.key,
    required this.paymentId,
    this.service,
    this.open,
    this.orderBuilder,
  }) : orderId = null;
  final String? orderId, paymentId;
  final PaymentService? service;
  final Future<bool> Function(Uri)? open;
  final Widget Function(String, List<String>)? orderBuilder;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  PaymentSession? _payment;
  bool _busy = false;
  String? _error;
  Timer? _retry;
  int _returnChecks = 0;
  bool _navigated = false;
  String? get _orderId => widget.orderId ?? _payment?.orderIds.firstOrNull;
  final _phoneForm = GlobalKey<FormState>();
  final _payerPhone = TextEditingController();
  bool get _needsPhone =>
      _payment?.payerPhoneRequired == true &&
      _payment?.status == 'awaiting_bill';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    _payerPhone.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _check();
  }

  Future<void> _check() async {
    if (_busy) return;
    _retry?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = widget.service ?? PaymentService();
      final payment = widget.paymentId != null
          ? await service.checkPayment(widget.paymentId!)
          : await service.check(widget.orderId!);
      if (!mounted) return;
      setState(() => _payment = payment);
      if (widget.paymentId != null) {
        if (payment.paid) {
          _viewOrder();
        } else if (payment.status == 'pending' && ++_returnChecks < 10) {
          _retry = Timer(const Duration(seconds: 3), _check);
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = OrderService.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _viewOrder() {
    final id = _orderId;
    if (id == null || _navigated) return;
    _navigated = true;
    final related = _payment?.orderIds ?? const <String>[];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/order'),
        builder: (_) =>
            widget.orderBuilder?.call(id, related) ??
            OrderTrackingScreen(orderId: id, relatedOrderIds: related),
      ),
    );
  }

  Future<void> _pay() async {
    if (_busy || _payment?.canPay != true) return;
    if (_needsPhone && _phoneForm.currentState?.validate() != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var payment = _payment!;
      if (payment.checkoutUri == null) {
        payment = await (widget.service ?? PaymentService()).start(
          _orderId!,
          payerPhone: _needsPhone ? _payerPhone.text.trim() : null,
        );
        if (!mounted) return;
        setState(() => _payment = payment);
        if (payment.canPay && payment.checkoutUri == null) {
          throw StateError(
            'Payment link is unavailable. Try again or contact the store.',
          );
        }
        // Opening the bank page is a separate user click, preserving browser
        // popup permission after the asynchronous bill creation request.
        return;
      }
      if (!payment.canPay) return;
      final uri = payment.checkoutUri;
      if (uri == null) {
        throw StateError(
          'Payment link is unavailable. Try again or contact the store.',
        );
      }
      final opened =
          await (widget.open?.call(uri) ??
              launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: '_blank',
              ));
      if (!opened) {
        throw StateError(
          'Could not open payment. Retry to open the same bill.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = OrderService.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    final message = payment == null
        ? 'Checking payment details…'
        : payment.paid
        ? 'Payment verified. Your order can now be prepared and delivered.'
        : payment.needsReview
        ? 'Your payment needs verification. Please wait or contact the store. Please do not create another order to retry payment.'
        : payment.status == 'expired'
        ? 'Payment expired. This order was cancelled and its reserved stock released.'
        : 'Payment is pending. Your order will proceed after payment is verified. If an attempt fails, reopen the same bill to retry.';
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('Order payment'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AppNote('Test payments only'),
          const SizedBox(height: 16),
          if (payment != null)
            Text(
              'Total RM ${(payment.totalSen / 100).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          const SizedBox(height: 12),
          Semantics(liveRegion: true, child: Text(message)),
          if (payment?.expiresAt != null &&
              !payment!.paid &&
              payment.status != 'expired')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Payment deadline: ${malaysiaTime(payment.expiresAt!)}',
              ),
            ),
          if (payment != null && payment.orderIds.length > 1)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: AppNote(
                'This single payment covers all deliveries in this checkout.',
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          if (_needsPhone && payment?.canPay == true) ...[
            Form(
              key: _phoneForm,
              child: TextFormField(
                controller: _payerPhone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Your phone number for payment',
                  hintText: '0123456789',
                  helperText:
                      'Use your own contact number for the payment receipt.',
                  helperMaxLines: 3,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your phone number to continue.'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (payment?.canPay == true)
            FilledButton(
              onPressed: _busy ? null : _pay,
              child: const Text('Pay Now'),
            ),
          if (_error != null)
            OutlinedButton(
              onPressed: _busy ? null : _check,
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: _orderId == null ? null : _viewOrder,
            child: const Text('View order'),
          ),
          if (payment?.paid != true)
            const AppNote(
              'You can reopen payment from your order details. Returning from the bank page alone does not confirm payment.',
            ),
        ],
      ),
    );
  }
}
