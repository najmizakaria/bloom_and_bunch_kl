import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/order_service.dart';
import '../../../core/widgets/page_navigation.dart';
import '../../../core/utils/malaysia_time.dart';
import 'order_tracking_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.orderId,
    this.service,
    this.open,
  });
  final String orderId;
  final PaymentService? service;
  final Future<bool> Function(Uri)? open;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  PaymentSession? _payment;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _check();
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payment = await (widget.service ?? PaymentService()).check(
        widget.orderId,
      );
      if (mounted) setState(() => _payment = payment);
    } catch (error) {
      if (mounted) setState(() => _error = OrderService.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    if (_busy || _payment?.canPay != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var payment = _payment!;
      if (payment.checkoutUri == null) {
        payment = await (widget.service ?? PaymentService()).start(
          widget.orderId,
        );
        if (!mounted) return;
        setState(() => _payment = payment);
        if (payment.canPay && payment.checkoutUri == null) {
          throw StateError(
            'Payment link is unavailable. Check payment status or contact the store.',
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
          'Payment link is unavailable. Check payment status or contact the store.',
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
        ? 'Your bill needs verification. Check status shortly or contact the store. Please do not create another order to retry payment.'
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
          const Text('ToyyibPay sandbox · Test payments only'),
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
              child: Text(
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
          if (payment?.canPay == true)
            FilledButton(
              onPressed: _busy ? null : _pay,
              child: Text(
                payment?.checkoutUri == null
                    ? 'Continue to payment'
                    : 'Open ToyyibPay sandbox',
              ),
            ),
          OutlinedButton(
            onPressed: _busy ? null : _check,
            child: const Text('Check payment status'),
          ),
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                builder: (_) => OrderTrackingScreen(orderId: widget.orderId),
              ),
            ),
            child: const Text('View order'),
          ),
          const Text(
            'You can reopen payment from your order details. Returning from the bank page alone does not confirm payment.',
          ),
        ],
      ),
    );
  }
}
