import 'package:bloom_and_bunch_kl/core/services/checkout_service.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mixed checkout explains each fee, demo payment and estimates at large text', (tester) async {
    tester.view.physicalSize=const Size(320,900);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final quote=CheckoutQuote({'quoteId':'test','mode':'demo','subtotalSen':10000,'deliveryFeeSen':1600,'totalSen':11600,
      'paymentInstructions':'Demo only; no payment collected.','timingNotice':'Estimated dispatch, not guaranteed arrival.',
      'groups':[{'kind':'ready_now','date':'2026-09-21','deliveryFeeSen':800},{'kind':'planned','date':'2026-09-23','deliveryFeeSen':800}]});
    await tester.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(2)),child: Scaffold(body: SingleChildScrollView(child: Padding(padding:const EdgeInsets.all(16),child:CheckoutSummary(quote:quote)))))));
    expect(find.text('Total: RM 116.00'),findsOneWidget);expect(find.text('Delivery: RM 16.00'),findsOneWidget);
    expect(find.textContaining('travel separately'),findsOneWidget);expect(find.textContaining('no payment collected'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
