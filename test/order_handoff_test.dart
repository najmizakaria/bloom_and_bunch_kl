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
  testWidgets(
    'assignment retries preserve the same request and selected rider',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderRiderAssignment(
              order: order(),
              load: (_) async => {
                'riders': [
                  {'id': 'rider_a', 'name': 'Amina'},
                ],
                'nextCursor': null,
              },
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
      await tester.tap(find.text('Confirm assignment'));
      await tester.pump();
      expect(find.text('Choose a rider first.'), findsOneWidget);
      await tester.tap(find.text('Amina'));
      await tester.pump();
      await tester.tap(find.text('Confirm assignment'));
      await tester.pumpAndSettle();
      expect(find.text('Connection interrupted'), findsOneWidget);
      await tester.tap(find.text('Confirm assignment'));
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      expect(requests[0]['riderId'], 'rider_a');
      expect(requests[0]['expectedRiderId'], isNull);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

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
    'empty eligible-rider pages can advance without losing the order',
    (tester) async {
      final cursors = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderRiderAssignment(
              order: order(),
              load: (cursor) async {
                cursors.add(cursor);
                return cursor == null
                    ? {'riders': [], 'nextCursor': 'next_page'}
                    : {
                        'riders': [
                          {'id': 'next_rider', 'name': 'Next rider'},
                        ],
                        'nextCursor': null,
                      };
              },
              submit: (_) async {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Assign rider'));
      await tester.pumpAndSettle();
      expect(find.text('Next riders'), findsNothing);
      expect(find.text('Next rider'), findsOneWidget);
      expect(cursors, [null, 'next_page']);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.text('Available to riders now — awaiting a rider.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('future bookings explain why assignment is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderRiderAssignment(
            order: order(extra: {'scheduledDeliveryDate': '2099-01-01'}),
          ),
        ),
      ),
    );
    expect(find.textContaining('Scheduled for 2099-01-01'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Assign rider'),
          )
          .onPressed,
      isNull,
    );
  });

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
