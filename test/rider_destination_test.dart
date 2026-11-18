import 'package:bloom_and_bunch_kl/models/delivery_job_model.dart';
import 'package:bloom_and_bunch_kl/models/order_model.dart';
import 'package:bloom_and_bunch_kl/features/rider/widgets/delivery_job_card.dart';
import 'package:bloom_and_bunch_kl/features/rider/widgets/rider_delivery_details.dart';
import 'package:bloom_and_bunch_kl/features/rider/screens/rider_available_job_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

DeliveryJobModel job({
  String? scheduled,
  String estimated = '2026-10-21',
  String address = '',
  Object? riderPaySen,
}) => DeliveryJobModel.fromMap({
  'orderId': 'BKQZMTTX1',
  'deliveryArea': 'Kajang · 43000',
  'deliveryAddress': address,
  'deliveryLocality': 'Kajang',
  'deliveryPostcode': '43000',
  'deliveryState': 'Selangor',
  'itemCount': 3,
  'riderPaySen': riderPaySen,
  'estimatedDispatchDate': estimated,
  'scheduledDeliveryDate': scheduled,
  'createdAt': 1792540800000,
}, 'BKQZMTTX1');

void main() {
  test(
    'destination and MYT delivery labels keep estimated and requested dates distinct',
    () {
      final now = DateTime.parse('2026-10-20T16:01:00Z');
      expect(job().destination, 'Kajang · 43000');
      expect(job().destinationArea, 'Kajang, Selangor');
      expect(job(riderPaySen: 850.0).riderPaySen, 850);
      expect(job(riderPaySen: 8.5).riderPaySen, isNull);
      final fullAddress = DeliveryJobModel.fromMap({
        'deliveryArea': 'Area needs confirmation',
        'deliveryAddress': 'Unit 12, Jalan Melati, 43000 Kajang, Selangor',
      }, 'legacy');
      expect(
        fullAddress.destination,
        'Unit 12, Jalan Melati, 43000 Kajang, Selangor',
      );
      expect(fullAddress.areaNeedsConfirmation, isFalse);
      expect(job().timingLabel(now: now), 'Estimated dispatch: Today, 21 Oct');
      expect(
        job(scheduled: '2026-10-22').timingLabel(now: now),
        'Requested delivery: Tomorrow, 22 Oct',
      );
      expect(
        job(estimated: '2026-10-16').dateWarning(now: now),
        'Dispatch date passed',
      );
      expect(
        job(scheduled: '2026-10-20').dateWarning(now: now),
        'Requested date passed',
      );
      expect(
        DeliveryJobModel.fromMap({
          'deliveryArea': 'Selangor, Malaysia',
        }, 'old').destination,
        'Area needs confirmation',
      );
    },
  );

  testWidgets(
    'destination cards and assigned details fit narrow screens with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Uri? openedMap;
      const maps = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(maps, (call) async {
        expect(call.method, 'launch');
        openedMap = Uri.parse(call.arguments['url'] as String);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(maps, null));
      var opened = false;
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
              child: Column(
                children: [
                  DeliveryJobCard(
                    job: job(
                      address:
                          'WQMX+JV, Unit 12, Jalan Melati, 43000 Kajang, Selangor, Kajang, 43000, Selangor',
                      riderPaySen: 850,
                    ),
                    onView: () => opened = true,
                  ),
                  RiderDeliveryDetails(
                    order: OrderModel.fromMap({
                      'deliveryAddress':
                          'Unit 5, Private Building, Jalan Test, 43000 Kajang, Selangor',
                      'recipientName': 'Test recipient',
                      'recipientPhone': '0123456789',
                      'deliveryNote': 'Call at the guardhouse before entering.',
                      'orderStatus': 'Out for Delivery',
                      'items': [
                        {'name': 'Bouquet', 'quantity': 1},
                        {'name': 'Plush Panda', 'quantity': 2, 'type': 'addon'},
                      ],
                    }, 'BKQZMTTX1'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final mapButton = find.text('Open in Maps');
      await tester.ensureVisible(mapButton);
      await tester.tap(mapButton);
      expect(openedMap?.host, 'www.google.com');
      expect(openedMap?.queryParameters['origin'], job().pickupAddress);
      expect(
        openedMap?.queryParameters['destination'],
        'Kajang, Selangor, Malaysia',
      );
      await tester.ensureVisible(find.text('View delivery'));
      await tester.tap(find.text('View delivery'));
      expect(opened, true);
      expect(
        find.text('Unit 12, Jalan Melati, 43000 Kajang, Selangor'),
        findsOneWidget,
      );
      expect(find.textContaining('WQMX+JV'), findsNothing);
      final availableCard = find.byType(DeliveryJobCard);
      expect(
        find.descendant(
          of: availableCard,
          matching: find.byIcon(Icons.schedule_outlined),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Estimated dispatch'), findsOneWidget);
      expect(find.textContaining('Dispatch date passed'), findsNothing);
      expect(find.text('RM 8.50'), findsOneWidget);
      expect(
        find.textContaining('Delivery area needs confirmation'),
        findsNothing,
      );
      expect(find.text('3 items to collect'), findsOneWidget);
      await tester.ensureVisible(find.text('Call recipient'));
      expect(find.text('Navigate'), findsOneWidget);
      expect(find.text('Delivery instructions'), findsOneWidget);
      await tester.ensureVisible(find.text('2 × Plush Panda · Add-on'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'available cards keep requested dates and show an area fallback',
    (tester) async {
      final delivery = job(scheduled: '2026-10-22', address: 'WQMX+JV');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeliveryJobCard(job: delivery)),
        ),
      );

      expect(find.text('Kajang, Selangor'), findsOneWidget);
      expect(find.text('WQMX+JV'), findsNothing);
      expect(find.text(delivery.timingLabel()), findsOneWidget);
    },
  );

  testWidgets(
    'lost acceptance race explains the change and returns to the refreshed list',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Delivery list')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => RiderAvailableJobScreen(
            job: job(),
            accept: (_) async {
              attempts++;
              throw FirebaseFunctionsException(
                code: 'failed-precondition',
                message: 'Another rider has accepted this delivery.',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept with confirmation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final thumb = find.byIcon(Icons.chevron_right);
      await tester.tap(thumb);
      await tester.drag(thumb, const Offset(75, 0));
      await tester.pumpAndSettle();
      expect(attempts, 0);
      await tester.drag(thumb, const Offset(750, 0));
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(find.text('Delivery unavailable'), findsOneWidget);
      await tester.tap(find.text('Back to deliveries'));
      await tester.pumpAndSettle();
      expect(find.text('Delivery list'), findsOneWidget);
      expect(find.byType(RiderAvailableJobScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
