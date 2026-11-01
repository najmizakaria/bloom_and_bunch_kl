import 'package:bloom_and_bunch_kl/core/widgets/firestore_page.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/bouquet_builder_screen.dart';
// ignore_for_file: subtype_of_sealed_class
import 'package:bloom_and_bunch_kl/features/admin/rider_history_screen.dart';
import 'dart:async';
import 'package:bloom_and_bunch_kl/core/constants/fulfillment_constants.dart';
import 'package:bloom_and_bunch_kl/core/services/bouquet_query.dart';
import 'package:bloom_and_bunch_kl/core/utils/malaysia_time.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/become_rider_screen.dart';
import 'package:bloom_and_bunch_kl/features/customer/widgets/product_components.dart';
import 'package:bloom_and_bunch_kl/features/rider/screens/rider_order_detail_screen.dart';
import 'package:bloom_and_bunch_kl/models/bouquet_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Regressions reproduced in the smoothness audit.
import 'package:bloom_and_bunch_kl/core/widgets/delivery_progress.dart';
import 'package:bloom_and_bunch_kl/features/florist/screens/florist_order_detail_screen.dart';
import 'package:bloom_and_bunch_kl/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel order(String status) => OrderModel(
  orderId: 'audit_order',
  customerId: 'audit_customer',
  totalAmount: 50,
  orderStatus: status,
  fulfillmentType: 'pre_order',
  recipientName: 'Recipient',
  recipientPhone: '0123456789',
  deliveryAddress: 'Test address',
  deliveryNote: '',
  deliveryTimeSlot: '',
  leadTimeBusinessDays: 2,
  requiresPrepTime: true,
  items: const [],
  createdAt: DateTime.utc(2026, 10, 5),
);

class _EmptyMetadata implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
  @override
  SnapshotMetadata get metadata => _EmptyMetadata();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyQuery implements Query<Map<String, dynamic>> {
  @override
  Query<Map<String, dynamic>> limit(int value) => this;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(_EmptySnapshot());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RetryQuery extends _EmptyQuery {
  final List<int> _calls = [0];
  int get calls => _calls[0];
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    _calls[0]++;
    return calls == 1
        ? Stream.error(StateError('offline'))
        : Stream.value(_EmptySnapshot());
  }
}

void main() {
  testWidgets('custom builder recovers a failed flower lookup with Retry', (
    tester,
  ) async {
    var subscriptions = 0;
    Stream<QuerySnapshot<Map<String, dynamic>>> watch() {
      subscriptions++;
      return subscriptions == 1
          ? Stream.error(StateError('Connection unavailable'))
          : Stream.value(_EmptySnapshot());
    }

    await tester.pumpWidget(
      MaterialApp(home: BouquetBuilderScreen(watchFlowers: watch)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(subscriptions, 1);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(subscriptions, 2);
    expect(
      find.text('No flowers are offered for custom bouquets right now.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'page error retry remains reachable in a short large-text viewport',
    (tester) async {
      final query = _RetryQuery();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: FirestorePage(
                query: query,
                builder: (_, docs) => const Text('Data'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(query.calls, 2);
      expect(find.text('No records found.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cursor page controls remain reachable in a short large-text viewport',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: FirestorePage(
                query: _EmptyQuery(),
                builder: (_, docs) => const Text('Data'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Reload'));
      expect(find.byTooltip('Reload').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'broken product image renders a fallback without an uncaught error',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 50,
              height: 50,
              child: ProductImage(
                imageUrl: 'https://example.invalid/missing.png',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.local_florist_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [const Size(320, 480), const Size(640, 320)]) {
    testWidgets('admin history filters fit $size at double text size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: RiderHistoryScreen(
            queryOverride: _EmptyQuery(),
            ridersLoader: (_) async => {
              'riders': [
                {
                  'uid': 'rider',
                  'name': 'A rider with a very long display name',
                },
              ],
              'next': null,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Reload'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byTooltip('Reload'), findsOneWidget);
    });
  }

  test(
    'receipt labels require recorded evidence, irrespective of workflow version',
    () {
      final data = {'orderStatus': 'Completed', 'deliveryWorkflowVersion': 2};
      expect(OrderModel.fromMap(data, 'old').receiptConfirmed, isFalse);
      data['customerAcceptedAt'] = Timestamp.fromDate(
        DateTime.utc(2026, 10, 5),
      );
      final recorded = OrderModel.fromMap(data, 'new');
      expect(recorded.receiptConfirmed, isTrue);
      expect(
        OrderStatuses.label(
          'Completed',
          receiptConfirmed: recorded.receiptConfirmed,
        ),
        contains('Receipt confirmed'),
      );
      expect(OrderStatuses.label('Completed'), contains('legacy'));
    },
  );
  test(
    'Pre-Order excludes ready-only products while retaining legacy ready products',
    () {
      final ready = BouquetModel.fromMap({
        'readyToSend': true,
        'stockCount': 5,
      }, 'legacy');
      expect(matchesBouquetMode(ready, BouquetMode.preOrder), isFalse);
      expect(matchesBouquetMode(ready, BouquetMode.readyNow), isTrue);
      final planned = BouquetModel.fromMap({
        'availableForPreOrder': true,
        'isPublished': true,
      }, 'planned');
      expect(matchesBouquetMode(planned, BouquetMode.preOrder), isTrue);
    },
  );
  test('MYT midnight uses the Malaysian day instead of the UTC day', () {
    final now = DateTime.utc(2026, 10, 4, 17);
    expect(isMalaysiaDay(DateTime.utc(2026, 10, 4, 16), now), isTrue);
    expect(isMalaysiaDay(DateTime.utc(2026, 10, 4, 15, 59), now), isFalse);
    expect(isMalaysiaDay(DateTime.utc(2026, 10, 5, 15, 59), now), isTrue);
  });
  testWidgets(
    'two open florist details update from a shared live order and cancel on disposal',
    (tester) async {
      final changes = StreamController<OrderModel?>.broadcast();
      Stream<OrderModel?> watch(String id) => changes.stream;
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              Expanded(
                child: FloristOrderDetailScreen(
                  order: order('Processing'),
                  watch: watch,
                ),
              ),
              Expanded(
                child: FloristOrderDetailScreen(
                  order: order('Processing'),
                  watch: watch,
                ),
              ),
            ],
          ),
        ),
      );
      changes.add(order('Processing'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Mark Ready to ship'), findsNWidgets(2));
      changes.add(order('Ready for Delivery'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Mark Ready to ship'), findsNothing);
      expect(find.text('Ready to ship'), findsWidgets);
      changes.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.text('This order is no longer available.'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(changes.hasListener, isFalse);
      await changes.close();
    },
  );
  testWidgets('live detail error offers retry and reconnects', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FloristOrderDetailScreen(
          order: order('Processing'),
          watch: (_) {
            calls++;
            return calls == 1
                ? Stream.error(StateError('offline'))
                : Stream.value(order('Ready for Delivery'));
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Ready to ship'), findsWidgets);
    expect(calls, 2);
  });
  testWidgets(
    'unknown or failed rider application lookup never presents the submit form',
    (tester) async {
      final lookup = StreamController<Map<String, dynamic>?>.broadcast();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BecomeRiderScreen(
            watchApplication: () {
              calls++;
              return calls == 1 ? lookup.stream : Stream.value(null);
            },
          ),
        ),
      );
      expect(find.text('Submit Application'), findsNothing);
      lookup.addError(StateError('offline'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Submit Application'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Submit Application'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await lookup.close();
    },
  );
  testWidgets('rapid favourite taps wait for the first operation', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductFavouriteButton(
            selected: false,
            onPressed: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(calls, 1);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    pending.complete();
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNotNull,
    );
  });
  for (final size in [
    const Size(320, 640),
    const Size(360, 640),
    const Size(390, 640),
    const Size(640, 320),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('florist and rider details fit $size at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final child in [
          FloristOrderDetailScreen(
            order: order('Processing'),
            watch: (_) => Stream.value(order('Processing')),
          ),
          RiderOrderDetailScreen(
            order: order('Completed'),
            watch: (_) => Stream.value(order('Completed')),
          ),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: child,
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets(
    'legacy completion without receipt evidence must not claim customer confirmation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryProgress(
              status: 'Completed',
              fulfillmentType: 'ready_now',
            ),
          ),
        ),
      );
      expect(find.text('Receipt confirmed — order completed'), findsNothing);
    },
  );

  testWidgets(
    'an updated florist order must replace the previous preparation status',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FloristOrderDetailScreen(
            order: order('Processing'),
            watch: (_) => Stream.value(order('Processing')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Preparing Bouquet'), findsWidgets);
      await tester.pumpWidget(
        MaterialApp(
          home: FloristOrderDetailScreen(
            order: order('Ready for Delivery'),
            watch: (_) => Stream.value(order('Ready for Delivery')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mark Ready to ship'), findsNothing);
      expect(find.text('Ready to ship'), findsWidgets);
    },
  );

  testWidgets('florist order detail fits width 320 at double text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: FloristOrderDetailScreen(
          order: order('Processing'),
          watch: (_) => Stream.value(order('Processing')),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
