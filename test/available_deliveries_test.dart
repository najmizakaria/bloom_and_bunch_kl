import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_and_bunch_kl/core/services/delivery_service.dart';
import 'package:bloom_and_bunch_kl/models/delivery_job_model.dart';
import 'package:bloom_and_bunch_kl/features/rider/widgets/available_deliveries_list.dart';
import 'package:bloom_and_bunch_kl/features/rider/screens/rider_available_job_screen.dart';

DeliveryJobModel job(String status) => DeliveryJobModel(
  orderId: 'test',
  deliveryArea: 'Kuala Lumpur',
  deliveryTimeSlot: 'Estimated dispatch tomorrow',
  requestedDeliveryDate: null,
  createdAt: DateTime(2026, 10, 6),
  orderStatus: status,
);
void main() {
  testWidgets('acceptance waits for preview exit before switching tabs', (
    tester,
  ) async {
    var switched = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvailableDeliveriesList(
            active: true,
            onMyDelivery: () => switched = true,
            load: (_) async =>
                AvailableDeliveryPage(deliveries: [job('Ready for Delivery')]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View delivery'));
    await tester.tap(find.text('View delivery'));
    await tester.pumpAndSettle();
    final preview = tester.element(find.byType(RiderAvailableJobScreen));
    // Simulate the successful callable result, without using Firebase.
    Navigator.of(preview).pop('test');
    await tester.pump();
    expect(switched, isFalse, reason: 'The preview is still animating out.');
    await tester.pumpAndSettle();
    expect(switched, isTrue);
    expect(find.byType(RiderAvailableJobScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('preparation records from an older service stay hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvailableDeliveriesList(
            active: true,
            onMyDelivery: () {},
            load: (_) async => AvailableDeliveryPage(
              deliveries: [
                job('Pending'),
                job('Awaiting Preparation'),
                job('Processing'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    expect(find.textContaining('Waiting for preparation'), findsNothing);
    expect(find.text('No available deliveries are waiting.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'missing rider callable shows delivery-specific error and can retry',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvailableDeliveriesList(
              active: true,
              onMyDelivery: () {},
              load: (_) async {
                if (++calls == 1) {
                  throw FirebaseFunctionsException(
                    code: 'not-found',
                    message: 'NOT FOUND',
                  );
                }
                return const AvailableDeliveryPage(deliveries: []);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The delivery list is currently unavailable. Please contact the store.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('order service'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No available deliveries are waiting.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final blocked in [false, true]) {
    testWidgets(
      'ready delivery acceptance respects active assignment $blocked',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RiderAvailableJobScreen(
              job: job('Ready for Delivery'),
              hasActiveDelivery: blocked,
            ),
          ),
        );
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, blocked ? isNull : isNotNull);
      },
    );
  }
  testWidgets('preparing order cannot be accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RiderAvailableJobScreen(job: job('Processing'))),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text('Waiting for preparation'), findsWidgets);
  });
  testWidgets(
    'delivery list retries failures and follows server cursor at double text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      Map<String, dynamic>? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: AvailableDeliveriesList(
                active: true,
                onMyDelivery: () {},
                load: (cursor) async {
                  calls++;
                  selected = cursor;
                  if (calls == 1) throw StateError('Connection interrupted');
                  return AvailableDeliveryPage(
                    deliveries: [job('Ready for Delivery')],
                    nextCursor: cursor == null
                        ? {'phase': 0, 'orderId': 'test'}
                        : null,
                    activeDeliveryId: 'active',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connection interrupted'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Retry'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Open My Delivery'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Ready for pickup'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Ready for pickup'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(selected, {'phase': 0, 'orderId': 'test'});
      await tester.scrollUntilVisible(
        find.textContaining('Ready for pickup'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Ready for pickup'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
