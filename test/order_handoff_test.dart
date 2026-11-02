import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_and_bunch_kl/models/order_model.dart';
import 'package:bloom_and_bunch_kl/core/services/delivery_service.dart';
import 'package:bloom_and_bunch_kl/core/widgets/delivery_progress.dart';
import 'package:bloom_and_bunch_kl/features/support/order_rider_assignment.dart';
import 'package:bloom_and_bunch_kl/features/rider/widgets/available_deliveries_list.dart';

OrderModel order({
  String status = 'Ready for Delivery',
  String? riderId,
  Map<String, dynamic> extra = const {},
}) => OrderModel.fromMap({
  'orderStatus': status,
  'riderId': riderId,
  'riderName': 'Current rider',
  'deliveryAddress': '12 Test Street',
  'latitude': 3.139,
  'longitude': 101.687,
  ...extra,
}, 'handoff_order');

void main() {
  testWidgets('one tap releases to the shared queue and errors can retry', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderRiderAssignment(
            order: order(),
            submit: (request) async {
              requests.add(request);
              if (requests.length == 1) {
                throw StateError('Connection interrupted');
              }
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Assign rider'));
    await tester.pumpAndSettle();
    expect(find.text('Connection interrupted'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Assign rider'));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(requests[0], requests[1]);
    expect(requests[0], {'action': 'release', 'expectedAssignmentRevision': 0});
    expect(
      find.text('Available to riders — waiting for acceptance.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Available to riders'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'unassignment requires a reason and sends the current rider as a precondition',
    (tester) async {
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderRiderAssignment(
              order: order(status: 'Rider assigned', riderId: 'old_rider'),
              submit: (request) async => submitted = request,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Unassign rider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unassign rider').last);
      await tester.pump();
      expect(find.text('Enter a reason.'), findsOneWidget);
      expect(submitted, isNull);
      await tester.enterText(
        find.byType(TextFormField),
        'Rider cannot collect',
      );
      await tester.tap(find.text('Unassign rider').last);
      await tester.pumpAndSettle();
      expect(submitted!['expectedRiderId'], 'old_rider');
      expect(submitted!['reason'], 'Rider cannot collect');
    },
  );

  testWidgets(
    'releasing waits for the pending call and prevents duplicate taps',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderRiderAssignment(
              order: order(),
              submit: (_) {
                calls++;
                return pending.future;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Assign rider'));
      await tester.tap(find.text('Assign rider'));
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Releasing…'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Available to riders'), findsOneWidget);
    },
  );

  testWidgets(
    'future orders release immediately without a rider picker or confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderRiderAssignment(
                order: order(extra: {'scheduledDeliveryDate': '2099-01-01'}),
                submit: (request) async => submitted = request,
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Scheduled for 2099-01-01'), findsOneWidget);
      await tester.ensureVisible(find.text('Assign rider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign rider'));
      await tester.pumpAndSettle();
      expect(submitted, {'action': 'release', 'expectedAssignmentRevision': 0});
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(
        find.text('Available to riders — waiting for acceptance.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a new assignment revision clears the released state', (
    tester,
  ) async {
    var current = order(extra: {'scheduledDeliveryDate': '2099-01-01'});
    late StateSetter update;
    final requests = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return OrderRiderAssignment(
                order: current,
                submit: (request) async => requests.add(request),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Assign rider'));
    await tester.pumpAndSettle();
    expect(find.text('Available to riders'), findsOneWidget);
    update(
      () => current = order(
        status: 'Rider assigned',
        riderId: 'rider',
        extra: {'assignmentRevision': 1},
      ),
    );
    await tester.pump();
    expect(find.text('Unassign rider'), findsOneWidget);
    update(
      () => current = order(
        extra: {'scheduledDeliveryDate': '2099-01-01', 'assignmentRevision': 2},
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Assign rider'));
    await tester.pumpAndSettle();
    expect(requests.last['expectedAssignmentRevision'], 2);
  });

  test(
    'future-date assignment still blocks unpaid, open-issue and invalid-address orders',
    () {
      for (final extra in [
        {'orderMode': 'toyyibpay_sandbox', 'paymentStatus': 'pending'},
        {
          'support': {'status': 'open'},
        },
        {'latitude': null, 'longitude': null},
      ]) {
        final future = order(
          extra: {'scheduledDeliveryDate': '2099-01-01', ...extra},
        );
        expect(future.isFutureDelivery, isTrue);
        expect(future.handoffBlockReason, isNotNull);
      }
      expect(
        order(extra: {'earlyDispatchDate': '2026-11-03'}).earlyDispatchDate,
        '2026-11-03',
      );
    },
  );

  testWidgets('assigned orders show collection pending in customer tracking', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeliveryProgress(
              status: 'Rider assigned',
              fulfillmentType: 'ready_now',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Rider assigned — awaiting collection'), findsWidgets);
    expect(find.text('Order received'), findsOneWidget);
    expect(find.text('Current status'), findsOneWidget);
  });

  testWidgets(
    'queue changes received during a load trigger another immediate refresh',
    (tester) async {
      final changes = StreamController<void>.broadcast();
      final pending = Completer<AvailableDeliveryPage>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvailableDeliveriesList(
              active: true,
              changes: changes.stream,
              onMyDelivery: () {},
              load: (_) {
                calls++;
                return calls == 1
                    ? pending.future
                    : Future.value(const AvailableDeliveryPage(deliveries: []));
              },
            ),
          ),
        ),
      );
      changes.add(null);
      await tester.pump();
      pending.complete(const AvailableDeliveryPage(deliveries: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(changes.hasListener, isFalse);
      await changes.close();
    },
  );
}
