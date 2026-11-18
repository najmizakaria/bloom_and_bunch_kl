import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/payment_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class OrderPaymentCountdown extends StatefulWidget {
  const OrderPaymentCountdown({
    super.key,
    required this.expiresAt,
    required this.checkPayment,
    required this.onPay,
    required this.onExpired,
    this.now = DateTime.now,
  });

  final DateTime? expiresAt;
  final Future<PaymentSession> Function() checkPayment;
  final VoidCallback onPay, onExpired;
  final DateTime Function() now;

  @override
  State<OrderPaymentCountdown> createState() => _OrderPaymentCountdownState();
}

class _OrderPaymentCountdownState extends State<OrderPaymentCountdown> {
  late DateTime? _deadline = widget.expiresAt;
  Timer? _timer;
  bool _checking = false, _failed = false;
  PaymentSession? _payment;

  int? get _secondsLeft {
    final remaining = _deadline?.difference(widget.now()).inMilliseconds;
    if (remaining == null) return null;
    return remaining <= 0 ? 0 : (remaining + 999) ~/ 1000;
  }

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    final seconds = _secondsLeft;
    if (seconds == null || seconds == 0) {
      unawaited(_check());
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft == 0) {
        unawaited(_check());
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _check() async {
    if (_checking) return;
    _timer?.cancel();
    setState(() {
      _checking = true;
      _failed = false;
    });
    try {
      final payment = await widget.checkPayment();
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _deadline = payment.expiresAt ?? _deadline;
        _checking = false;
      });
      if (payment.status == 'expired') {
        widget.onExpired();
      } else if (!payment.paid && !payment.needsReview) {
        if (_secondsLeft == 0) {
          // Stripe can still be reconciling an in-flight payment at the deadline.
          _timer = Timer(const Duration(seconds: 5), _check);
        } else if (_deadline == null) {
          setState(() => _failed = true);
        } else {
          _startCountdown();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_payment?.paid == true) return const SizedBox.shrink();
    if (_payment?.needsReview == true) {
      return const Text('Your payment is under review.');
    }
    if (_payment?.status == 'expired') return const Text('Payment expired');

    final seconds = _secondsLeft;
    final time = seconds == null
        ? null
        : '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final mayPay = !_checking && !_failed && seconds != null && seconds > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              time == null ? 'Checking payment deadline…' : 'Pay within $time',
              style: const AppTypography.label(color: AppColors.primaryDark),
            ),
          ),
        ),
        if (_failed) ...[
          const Text('Could not check payment status.'),
          TextButton(
            onPressed: _check,
            child: const Text('Retry payment status'),
          ),
        ] else if (seconds == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Checking payment status…',
              textAlign: TextAlign.center,
            ),
          ),
        FilledButton(
          onPressed: mayPay
              ? () {
                  if (_secondsLeft == 0) {
                    unawaited(_check());
                  } else {
                    widget.onPay();
                  }
                }
              : null,
          child: const Text('View payment / pay'),
        ),
      ],
    );
  }
}
