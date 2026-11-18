// ignore_for_file: subtype_of_sealed_class
import 'package:bloom_and_bunch_kl/features/florist/screens/florist_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Order extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  String get id => 'order';

  @override
  Map<String, dynamic> data() => {
    'orderStatus': 'Awaiting Preparation',
    'createdAt': Timestamp.now(),
    'recipientName': 'Test Recipient',
    'estimatedDispatchDate': '2026-11-19',
    'items': [
      {'type': 'addon', 'imageUrl': 'https://example.test/bear.png'},
      {
        'type': 'ready',
        'name': 'Always & Forever',
        'imageUrl': 'https://example.test/bouquet.png',
      },
    ],
  };
}

void main() {
  testWidgets('compact order grid keeps the stock bar and attention in view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? orderFilter;
    int? productTab;

    await tester.pumpWidget(
      MaterialApp(
        home: FloristDashboardScreen(
          onOpenOrders: (status) => orderFilter = status,
          onOpenProducts: (tab) => productTab = tab,
          watchOrders: () => Stream.value(_Snapshot([_Order()])),
          watchFlowers: () => Stream.value(_Snapshot([])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Rect tile(String label) => tester.getRect(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
    );
    expect(find.text('1 order today'), findsOneWidget);
    final first = tile('New');
    final second = tile('Preparing');
    final third = tile('Ready');
    final fourth = tile('Rider assigned');
    final stock = tile('Low Stock (preview)');
    expect(second.top, first.top);
    expect(fourth.top, third.top);
    expect(third.top, greaterThan(first.bottom));
    expect(first.left, third.left);
    expect(stock.left, first.left);
    expect(stock.right, second.right);
    expect(stock.top, greaterThan(third.bottom));
    expect(stock.height, lessThan(first.height));
    expect(find.text('Everything looks great!').hitTestable(), findsOneWidget);
    expect(find.text('Up Next').hitTestable(), findsOneWidget);
    final dispatch = find.text('Dispatch: Thu, 19 Nov 2026');
    expect(dispatch, findsOneWidget);
    expect(tester.getBottomLeft(dispatch).dy, lessThan(700));
    final bouquet = find.image(
      const NetworkImage('https://example.test/bouquet.png'),
    );
    expect(bouquet, findsOneWidget);
    expect(
      tester.getTopRight(bouquet).dx,
      lessThan(tester.getTopLeft(find.text('Test Recipient')).dx),
    );

    await tester.tap(find.text('Ready'));
    expect(orderFilter, 'Ready for Delivery');
    await tester.tap(find.text('Low Stock (preview)'));
    expect(productTab, 1);
    expect(tester.takeException(), isNull);
  });
}
