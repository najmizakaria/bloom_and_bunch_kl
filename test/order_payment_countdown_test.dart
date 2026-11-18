import 'package:bloom_and_bunch_kl/core/services/payment_service.dart';
import 'package:bloom_and_bunch_kl/features/customer/widgets/order_payment_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentSession session(String status, DateTime deadline) => PaymentSession(
  id: 'payment',
  status: status,
  totalSen: 1500,
  orderIds: const ['order'],
  expiresAt: deadline,
  provider: 'stripe',
);

void main() {
  testWidgets('countdown keeps the deadline when reopened and checks expiry', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 19);
    final deadline = now.add(const Duration(minutes: 30));
    var checks = 0;
    var expired = 0;
    var openings = 0;
    Widget screen() => MaterialApp(
      home: Scaffold(
        body: OrderPaymentCountdown(
          expiresAt: deadline,
          now: () => now,
          checkPayment: () async =>
              session(++checks == 1 ? 'pending' : 'expired', deadline),
          onPay: () => openings++,
          onExpired: () => expired++,
        ),
      ),
    );

    await tester.pumpWidget(screen());
    expect(find.text('Pay within 30:00'), findsOneWidget);
    await tester.tap(find.text('View payment / pay'));
    expect(openings, 1);
    expect(checks, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    now = deadline.subtract(const Duration(seconds: 1));
    await tester.pumpWidget(screen());
    expect(find.text('Pay within 00:01'), findsOneWidget);

    now = deadline;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    final pay = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(pay.onPressed, isNull);
    expect(find.text('Pay within 00:00'), findsOneWidget);
    expect(checks, 1);
    expect(expired, 0);

    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(checks, 2);
    expect(expired, 1);
    expect(find.text('Payment expired'), findsOneWidget);
  });

  testWidgets('older orders fetch the deadline and a successful payment wins', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 19);
    final deadline = now.add(const Duration(minutes: 12));
    var checks = 0;
    var expired = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderPaymentCountdown(
            expiresAt: null,
            now: () => now,
            checkPayment: () async =>
                session(++checks == 1 ? 'pending' : 'paid', deadline),
            onPay: () {},
            onExpired: () => expired = true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Pay within 12:00'), findsOneWidget);

    now = deadline;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(checks, 2);
    expect(expired, isFalse);
    expect(find.textContaining('Pay within'), findsNothing);
    expect(find.text('View payment / pay'), findsNothing);
  });
}
