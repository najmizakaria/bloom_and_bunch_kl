import 'dart:async';
import 'package:bloom_and_bunch_kl/core/services/rider_contact_service.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
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
    'rider contact saves an arbitrary number without separate approval',
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
      expect(find.text('Contact missing'), findsOneWidget);
      await tester.tap(find.byTooltip('Actions for Legacy Rider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit delivery contact'));
      await tester.pumpAndSettle();
      expect(find.byType(RiderContactEditor), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save contact'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.tap(find.text('Save contact'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('Enter a phone number'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, '676766767');
      await tester.ensureVisible(find.text('Save contact'));
      await tester.tap(find.text('Save contact'));
      await tester.pumpAndSettle();
      expect(saved?['phone'], '676766767');
      expect(saved?.containsKey('confirmed'), false);
      expect(saved?['contactVersion'], 'version-one');
      expect(find.byType(RiderContactEditor), findsNothing);
      expect(find.text('Contact available'), findsOneWidget);
    },
  );

  testWidgets('new delivery acceptance explains missing contact details', (
    tester,
  ) async {
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
    expect(find.text('Delivery contact missing'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.textContaining('Ask the store administrator'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets(
    'florist can follow live delivery transitions and see the assigned rider',
    (tester) async {
      tester.view.physicalSize = const Size(390, 790);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final streams = <String, StreamController<List<OrderModel>>>{};
      Stream<List<OrderModel>> watch(String status) =>
          (streams[status] ??= StreamController<List<OrderModel>>.broadcast())
              .stream;
      OrderModel order(
        String status, {
        String id = 'order123',
      }) => OrderModel.fromMap({
        'orderStatus': status,
        'riderId': status == 'Ready for Delivery' ? null : 'rider',
        'riderName': 'Approved Rider',
        'recipientName': 'Recipient',
        'totalAmount': 22,
        'deliveryTimeSlot':
            'Estimated dispatch depends on preparation and rider availability.',
        'items': [
          {
            'type': 'ready',
            'name': 'Lavender Blush',
            'imageUrl': 'https://example.test/lavender.png',
            'unitPrice': 10,
            'quantity': 2,
          },
        ],
      }, id);
      await tester.pumpWidget(
        MaterialApp(home: FloristOrdersScreen(watchOrders: watch)),
      );
      final header = tester.widget<AppBar>(find.byType(AppBar));
      expect(header.centerTitle, isTrue);
      expect(header.titleTextStyle?.color, AppColors.onPrimary);
      for (final entry in {
        'New': 'Awaiting Preparation',
        'Preparing': 'Processing',
        'Ready to ship': 'Ready for Delivery',
        'Assigned': 'Rider assigned',
        'Delivering': 'Out for Delivery',
        'Awaiting receipt': 'Awaiting Customer Confirmation',
        'Completed': 'Completed',
        'Cancelled': 'Cancelled',
      }.entries) {
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, entry.key));
        await tester.tap(find.widgetWithText(ChoiceChip, entry.key));
        await tester.pump();
        streams[entry.value]!.add([
          order(entry.value),
          if (entry.key == 'Completed') order('Delivered', id: 'legacy-order'),
        ]);
        await tester.pumpAndSettle();
        expect(find.text('ORDER #ORDER123'), findsOneWidget);
        expect(
          find.textContaining('Estimated dispatch depends on preparation'),
          findsWidgets,
        );
        expect(find.text('Recipient'), findsWidgets);
        expect(find.text('1 item(s)'), findsWidgets);
        expect(find.text('RM 22.00'), findsWidgets);
        expect(find.text('Lavender Blush'), findsWidgets);
        expect(
          find.image(const NetworkImage('https://example.test/lavender.png')),
          findsWidgets,
        );
        expect(find.text('RM 20.00'), findsWidgets);
        if (entry.key == 'Preparing') {
          final progress = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(progress.semanticsLabel, 'Order progress: Preparation');
          expect(progress.value, closeTo(2 / 7, 0.001));
        }
        final selected = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, entry.key),
        );
        expect(selected.selected, isTrue);
        expect(selected.selectedColor, AppColors.primary);
        expect(selected.labelStyle?.color, AppColors.onPrimary);
        if (entry.key == 'Completed') {
          expect(
            find.widgetWithText(ChoiceChip, 'Delivered (older)'),
            findsNothing,
          );
          expect(find.text('DELIVERED (OLDER)'), findsOneWidget);
        }
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
