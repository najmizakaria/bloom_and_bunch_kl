import 'package:bloom_and_bunch_kl/core/constants/fulfillment_constants.dart';
import 'package:bloom_and_bunch_kl/core/utils/order_tracking_display.dart';
import 'package:bloom_and_bunch_kl/features/customer/widgets/order_tracking_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracking formats new and old numbers, dates, and saved addresses', () {
    expect(trackingOrderNumber('#ORDER0001'), '#0001');
    expect(trackingOrderNumber('#QFGGANN5'), '#QFGGANN5');
    expect(trackingDate('2026-11-19'), 'Thu, 19 Nov 2026');
    expect(trackingDate('To be confirmed'), 'To be confirmed');
    expect(
      trackingAddress(
        'WQMX+JV, 43000 Kajang, Selangor, Malaysia, Kajang, 43000, Selangor, Malaysia',
      ),
      '43000 Kajang, Selangor, Malaysia',
    );
    expect(
      trackingAddress('Unit 4, Block A, Jalan Reko, 43000 Kajang'),
      'Unit 4, Block A, Jalan Reko, 43000 Kajang',
    );
    expect(trackingAddress('WQMX+JV'), 'WQMX+JV');
  });

  testWidgets('payment comes before arranging or delivery on a narrow screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SingleChildScrollView(
                  child: OrderTrackingProgress(
                    status: OrderStatuses.readyForDelivery,
                    paymentStatus: 'pending',
                    receiptConfirmed: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Payment verification, current step'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Bouquet being prepared, upcoming'),
      findsOneWidget,
    );
    expect(find.text('Current status'), findsOneWidget);
    expect(find.textContaining('We’re checking your payment!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a verified order advances to On the Way after collection', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrderTrackingProgress(
            status: OrderStatuses.outForDelivery,
            paymentStatus: 'paid',
            receiptConfirmed: false,
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Payment verification, complete'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('On the way, current step'), findsOneWidget);
    expect(find.textContaining('We’re checking your payment!'), findsNothing);
  });

  testWidgets('ready-to-send orders skip preparation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrderTrackingProgress(
            status: OrderStatuses.readyForDelivery,
            paymentStatus: 'paid',
            receiptConfirmed: false,
            fulfillmentType: FulfillmentTypes.readyNow,
          ),
        ),
      ),
    );
    expect(find.text('Bouquet being prepared'), findsNothing);
    expect(
      find.bySemanticsLabel('Ready to ship, current step'),
      findsOneWidget,
    );
  });
}
