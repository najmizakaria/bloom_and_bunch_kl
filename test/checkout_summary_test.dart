import 'package:bloom_and_bunch_kl/core/services/checkout_service.dart';
import 'package:bloom_and_bunch_kl/core/widgets/app_note.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in [
    'demo',
    'toyyibpay_sandbox',
    'stripe_sandbox',
    'stripe_live',
    'manual',
  ]) {
    testWidgets(
      'mixed checkout shows totals without a payment section at double text ($mode)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final quote = CheckoutQuote({
          'quoteId': 'test',
          'mode': mode,
          'subtotalSen': 10000,
          'deliveryFeeSen': 0,
          'totalSen': 10000,
          'groups': [
            {'kind': 'ready_now', 'date': '2026-09-21', 'deliveryFeeSen': 0},
            {'kind': 'planned', 'date': '2026-09-23', 'deliveryFeeSen': 0},
          ],
        });
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CheckoutSummary(quote: quote),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Total: RM 100.00'), findsOneWidget);
        expect(find.textContaining('Delivery:'), findsNothing);
        expect(find.textContaining('delivery fee'), findsNothing);
        expect(find.textContaining('Demo'), findsNothing);
        expect(find.textContaining('ToyyibPay'), findsNothing);
        expect(find.textContaining('sandbox'), findsNothing);
        expect(find.text('Payment method'), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(AppNote), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
