import 'package:bloom_and_bunch_kl/core/services/checkout_service.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'mixed checkout shows item total and neutral payment wording at double text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final quote = CheckoutQuote({
        'quoteId': 'test',
        'mode': 'demo',
        'subtotalSen': 10000,
        'deliveryFeeSen': 0,
        'totalSen': 10000,
        'paymentInstructions': 'Demo only; no payment collected.',
        'timingNotice': 'Demo only.',
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
      expect(find.textContaining('travel separately'), findsOneWidget);
      expect(find.textContaining('does not confirm payment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
