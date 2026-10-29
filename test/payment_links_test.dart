import 'dart:async';
import 'package:bloom_and_bunch_kl/core/services/payment_links.dart';
import 'package:bloom_and_bunch_kl/core/widgets/payment_link_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final id = List.filled(64, 'a').join();
  test(
    'only the registered return URL with one valid payment ID is accepted',
    () {
      expect(
        paymentIdFromLink(
          Uri.parse('bloombunch://payment-return?payment_id=$id&status_id=1'),
        ),
        id,
      );
      for (final url in [
        'https://payment-return?payment_id=$id',
        'bloombunch://other?payment_id=$id',
        'bloombunch://evil@payment-return?payment_id=$id',
        'bloombunch://payment-return:80?payment_id=$id',
        'bloombunch://payment-return/path?payment_id=$id',
        'bloombunch://payment-return?payment_id=$id#success',
        'bloombunch://payment-return?payment_id=$id&payment_id=$id',
        'bloombunch://payment-return?payment_id=../orders',
        'bloombunch://payment-return?status_id=1',
      ]) {
        expect(paymentIdFromLink(Uri.parse(url)), isNull, reason: url);
      }
    },
  );

  testWidgets(
    'cold return waits for sign in; warm return clears stale routes and deduplicates',
    (tester) async {
      final links = ValueNotifier<String?>(id);
      final auth = StreamController<String?>.broadcast(sync: true);
      addTearDown(auth.close);
      final navigator = GlobalKey<NavigatorState>();
      final observer = PaymentLinkNavigatorObserver();
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          builder: (_, child) => PaymentLinkSession(
            links: links,
            authIds: auth.stream,
            navigatorKey: navigator,
            routeChanges: observer.changes,
            paymentBuilder: (paymentId) {
              opened++;
              return Scaffold(body: Text('Payment $paymentId'));
            },
            child: child!,
          ),
          home: const Scaffold(body: Text('Sign in')),
        ),
      );
      auth.add(null);
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(links.value, id);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Text('Google sign in finishing')),
        ),
      );
      await tester.pumpAndSettle();
      auth.add('buyer');
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(links.value, id);
      navigator.currentState!.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      expect(find.text('Payment $id'), findsOneWidget);
      expect(opened, 1);
      links.value = id;
      await tester.pumpAndSettle();
      expect(opened, 1);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('Old payment')),
      );
      await tester.pumpAndSettle();
      links.value = id;
      await tester.pumpAndSettle();
      expect(find.text('Payment $id'), findsOneWidget);
      expect(opened, 2);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Old payment'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      links.dispose();
      observer.changes.dispose();
    },
  );
}
