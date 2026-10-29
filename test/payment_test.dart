import 'dart:async';
import 'package:bloom_and_bunch_kl/core/services/payment_service.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/payment_screen.dart';
import 'package:bloom_and_bunch_kl/features/florist/screens/florist_order_detail_screen.dart';
import 'package:bloom_and_bunch_kl/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentSession session(
  String status, {
  String? url,
  bool phoneRequired = false,
}) => PaymentSession(
  id: 'payment',
  status: status,
  totalSen: 5500,
  orderIds: const ['one', 'two'],
  paymentUrl: url,
  payerPhoneRequired: phoneRequired,
  expiresAt: DateTime.now().add(const Duration(minutes: 30)),
);

class Payments implements PaymentService {
  PaymentSession current = session('awaiting_bill');
  int starts = 0;
  bool failCheck = false;
  String? submittedPhone;
  String? checkedPaymentId;
  @override
  Future<PaymentSession> checkPayment(String paymentId) async {
    checkedPaymentId = paymentId;
    return check('one');
  }

  @override
  Future<PaymentSession> check(String orderId) async {
    if (failCheck) throw StateError('Check failed. Retry shortly.');
    return current;
  }

  @override
  Future<PaymentSession> start(String orderId, {String? payerPhone}) async {
    starts++;
    submittedPhone = payerPhone;
    return current = session(
      'pending',
      url: 'https://dev.toyyibpay.com/testbill',
    );
  }
}

void main() {
  testWidgets(
    'native return verifies payment ID then opens all checkout orders',
    (tester) async {
      final service = Payments()..current = session('paid');
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen.fromReturn(
            paymentId: 'returned-payment',
            service: service,
            orderBuilder: (id, related) =>
                Scaffold(body: Text('Order $id: ${related.join(",")}')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.checkedPaymentId, 'returned-payment');
      expect(find.text('Order one: one,two'), findsOneWidget);
      expect(service.starts, 0);
    },
  );

  testWidgets(
    'native return polls pending payment and navigates only once verified',
    (tester) async {
      final service = Payments()..current = session('pending');
      var ordersOpened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen.fromReturn(
            paymentId: 'returned-payment',
            service: service,
            orderBuilder: (id, related) {
              ordersOpened++;
              return const Scaffold(body: Text('Verified order'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Payment is pending'), findsOneWidget);
      expect(ordersOpened, 0);
      service.current = session('paid');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Verified order'), findsOneWidget);
      expect(ordersOpened, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(ordersOpened, 1);
    },
  );

  testWidgets(
    'unauthorized or failed return offers retry without opening an order',
    (tester) async {
      final service = Payments()..failCheck = true;
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen.fromReturn(
            paymentId: 'returned-payment',
            service: service,
            orderBuilder: (_, _) => const Text('Must not open'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Check failed. Retry shortly.'), findsOneWidget);
      expect(find.text('Must not open'), findsNothing);
      service.failCheck = false;
      service.current = session('paid');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Must not open'), findsOneWidget);
    },
  );

  testWidgets(
    'new account enters payer phone on payment screen without creating another order',
    (tester) async {
      final service = Payments()
        ..current = session('awaiting_bill', phoneRequired: true);
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(orderId: 'one', service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your phone number for payment'), findsOneWidget);
      await tester.ensureVisible(find.text('Pay Now'));
      await tester.tap(find.text('Pay Now'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your phone number to continue.'), findsOneWidget);
      expect(service.starts, 0);
      await tester.enterText(find.byType(TextFormField), '+60 12-3456789');
      await tester.ensureVisible(find.text('Pay Now'));
      await tester.tap(find.text('Pay Now'));
      await tester.pumpAndSettle();
      expect(service.submittedPhone, '+60 12-3456789');
      expect(service.starts, 1);
      expect(find.text('Pay Now'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    },
  );
  testWidgets('florist preparation unlocks only after verified payment', (
    tester,
  ) async {
    final changes = StreamController<OrderModel?>();
    addTearDown(changes.close);
    OrderModel order(String payment) => OrderModel.fromMap({
      'orderMode': 'toyyibpay_sandbox',
      'paymentStatus': payment,
      'orderStatus': 'Awaiting Preparation',
      'customerId': 'buyer',
    }, 'test');
    await tester.pumpWidget(
      MaterialApp(
        home: FloristOrderDetailScreen(
          order: order('pending'),
          watch: (_) => changes.stream,
        ),
      ),
    );
    changes.add(order('pending'));
    await tester.pumpAndSettle();
    expect(find.text('Awaiting Payment'), findsWidgets);
    expect(find.text('Start Preparing'), findsNothing);
    changes.add(order('paid'));
    await tester.pumpAndSettle();
    expect(find.text('Start Preparing'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('payment URLs accept only sandbox HTTPS bill links', () {
    expect(
      session('pending', url: 'https://dev.toyyibpay.com/bill').checkoutUri,
      isNotNull,
    );
    for (final url in [
      'http://dev.toyyibpay.com/bill',
      'https://toyyibpay.com/bill',
      'https://dev.toyyibpay.com.evil.test/bill',
      'https://evil@dev.toyyibpay.com/bill',
      'https://dev.toyyibpay.com/bill?next=evil',
      'https://dev.toyyibpay.com:444/bill',
    ]) {
      expect(session('pending', url: url).checkoutUri, isNull);
    }
  });

  testWidgets(
    'bank return stays pending until backend verification; payment covers all deliveries',
    (tester) async {
      final service = Payments();
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(
            orderId: 'one',
            service: service,
            open: (uri) async {
              opened = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total RM 55.00'), findsOneWidget);
      expect(find.textContaining('covers all deliveries'), findsOneWidget);
      expect(find.textContaining('ToyyibPay'), findsNothing);
      expect(find.textContaining('sandbox'), findsNothing);
      await tester.tap(find.text('Pay Now'));
      await tester.pumpAndSettle();
      expect(opened, isNull);
      await tester.tap(find.text('Pay Now'));
      await tester.pumpAndSettle();
      expect(opened.toString(), 'https://dev.toyyibpay.com/testbill');
      expect(find.textContaining('Payment is pending'), findsOneWidget);
      expect(find.text('Check payment status'), findsNothing);
      service.current = session('paid');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.textContaining('Payment verified.'), findsOneWidget);
      expect(find.text('Pay Now'), findsNothing);
      expect(find.text('Check payment status'), findsNothing);
      expect(find.textContaining('You can reopen payment'), findsNothing);
      expect(service.starts, 1);
    },
  );

  testWidgets('uncertain bill creation cannot start another payment', (
    tester,
  ) async {
    final service = Payments()..current = session('creation_unknown');
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(orderId: 'one', service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Please do not create another order'),
      findsOneWidget,
    );
    expect(find.text('Pay Now'), findsNothing);
  });

  testWidgets('failed status check exposes retry and recovers', (tester) async {
    final service = Payments()..failCheck = true;
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(orderId: 'one', service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Check failed. Retry shortly.'), findsOneWidget);
    service.failCheck = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Pay Now'), findsOneWidget);
  });
}
