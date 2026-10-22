import 'dart:async';
import 'package:bloom_and_bunch_kl/core/services/rider_contact_service.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_riders_screen.dart';
import 'package:bloom_and_bunch_kl/features/admin/rider_contact_editor.dart';
import 'package:bloom_and_bunch_kl/features/florist/screens/florist_orders_screen.dart';
import 'package:bloom_and_bunch_kl/features/rider/screens/rider_available_job_screen.dart';
import 'package:bloom_and_bunch_kl/models/delivery_job_model.dart';
import 'package:bloom_and_bunch_kl/models/order_model.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'customer contact errors hide transport codes and preserve assignment guidance',
    () {
      expect(
        RiderContactService.message(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Rider contact is unavailable. [400]',
          ),
        ),
        'Rider contact is unavailable. Please call the florist.',
      );
      expect(
        RiderContactService.message(
          StateError('The rider assignment changed. Please reopen this order.'),
        ),
        'The rider assignment changed. Please reopen this order.',
      );
    },
  );

  testWidgets(
    'an idle rider without contact still has an admin review action',
    (tester) async {
      Map<String, dynamic>? saved;
      var ready = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminRiderDirectory(
              ridersLoader: (_) async => {
                'riders': [
                  {
                    'uid': 'legacy',
                    'name': 'Legacy Rider',
                    'contactName': 'Legacy Rider',
                    'contactPhone': '',
                    'contactVersion': 'version-one',
                    'contactReady': ready,
                  },
                ],
              },
              contactSaver: (data) async {
                saved = data;
                ready = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Contact needs review'), findsOneWidget);
      await tester.tap(find.byTooltip('Actions for Legacy Rider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review delivery contact'));
      await tester.pumpAndSettle();
      expect(find.byType(RiderContactEditor), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Approve contact'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve contact'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('valid Malaysian phone'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).last,
        '+60 12-345 6789',
      );
      await tester.ensureVisible(find.text('Approve contact'));
      await tester.tap(find.text('Approve contact'));
      await tester.pumpAndSettle();
      expect(saved?['phone'], '+60123456789');
      expect(saved?['confirmed'], true);
      expect(saved?['contactVersion'], 'version-one');
      expect(find.byType(RiderContactEditor), findsNothing);
      expect(find.text('Contact approved'), findsOneWidget);
    },
  );

  testWidgets(
    'new delivery acceptance is disabled with actionable contact review guidance',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RiderAvailableJobScreen(
            job: DeliveryJobModel.fromMap({
              'orderStatus': 'Ready for Delivery',
              'deliveryAddress': '12 Main Street, Kuala Lumpur',
            }, 'job'),
            contactReady: false,
            accept: (_) async {
              calls++;
            },
          ),
        ),
      );
      expect(find.text('Delivery contact needs review'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(
        find.textContaining('Ask the store administrator'),
        findsOneWidget,
      );
      expect(calls, 0);
    },
  );

  testWidgets(
    'florist can follow live delivery transitions and see the assigned rider',
    (tester) async {
      final streams = <String, StreamController<List<OrderModel>>>{};
      Stream<List<OrderModel>> watch(String status) =>
          (streams[status] ??= StreamController<List<OrderModel>>.broadcast())
              .stream;
      OrderModel order(String status) => OrderModel.fromMap({
        'orderStatus': status,
        'riderId': status == 'Ready for Delivery' ? null : 'rider',
        'riderName': 'Approved Rider',
        'recipientName': 'Recipient',
        'items': <Map<String, dynamic>>[],
      }, 'order123');
      await tester.pumpWidget(
        MaterialApp(home: FloristOrdersScreen(watchOrders: watch)),
      );
      for (final entry in {
        'Ready': 'Ready for Delivery',
        'Delivering': 'Out for Delivery',
        'Awaiting receipt': 'Awaiting Customer Confirmation',
        'Completed': 'Completed',
      }.entries) {
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, entry.key));
        await tester.tap(find.widgetWithText(ChoiceChip, entry.key));
        await tester.pump();
        streams[entry.value]!.add([order(entry.value)]);
        await tester.pumpAndSettle();
        expect(find.text('ORDER #ORDER123'), findsOneWidget);
        if (entry.key == 'Delivering') {
          expect(find.text('DELIVERING'), findsOneWidget);
          expect(find.text('Assigned rider: Approved Rider'), findsOneWidget);
          streams[entry.value]!.add([]);
          await tester.pumpAndSettle();
          expect(find.text('No orders are out for delivery'), findsOneWidget);
        }
      }
      await tester.pumpWidget(const SizedBox());
      for (final stream in streams.values) {
        await stream.close();
      }
    },
  );
}
