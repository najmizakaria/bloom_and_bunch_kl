import 'package:bloom_and_bunch_kl/features/admin/admin_orders_screen.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_widgets.dart';
import 'package:bloom_and_bunch_kl/core/services/admin_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin errors explain service failures and preserve action guidance', () {
    expect(
      AdminService.message(
        FirebaseFunctionsException(code: 'internal', message: 'internal [0]'),
      ),
      'The admin service could not be reached. Please retry or contact the store administrator.',
    );
    expect(
      AdminService.message(
        FirebaseFunctionsException(code: 'unauthenticated', message: ''),
      ),
      contains('Please sign in again'),
    );
    expect(
      AdminService.message(
        FirebaseFunctionsException(code: 'permission-denied', message: ''),
      ),
      contains('Administrator access is required'),
    );
    expect(
      AdminService.message(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'This rider still has assigned deliveries.',
        ),
      ),
      'This rider still has assigned deliveries.',
    );
  });
  testWidgets(
    'callable transport failure shows readable guidance and retries',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminLoad(
              load: () async {
                if (attempts++ == 0) {
                  throw FirebaseFunctionsException(
                    code: 'internal',
                    message: 'internal [0]',
                  );
                }
                return {'count': 3};
              },
              builder: (data, refresh) => Text('Riders: ${data['count']}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('admin service could not be reached'),
        findsOneWidget,
      );
      expect(find.text('internal [0]'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Riders: 3'), findsOneWidget);
    },
  );
  testWidgets('desktop orders use a compact scrollable table', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminOrdersScreen(
          ordersLoader: (p) async => {
            'orders': [
              {
                'id': 'desktop-order',
                'recipientName': 'Recipient',
                'totalAmount': 12,
                'orderStatus': 'Processing',
                'fulfillmentType': 'custom',
                'paymentStatus': 'paid',
                'orderMode': 'manual',
              },
            ],
            'next': null,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Recipient'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'admin data errors offer a working retry instead of hiding the failure',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminLoad(
              load: () async {
                if (attempts++ == 0) {
                  throw StateError('Temporary service failure');
                }
                return {'count': 4};
              },
              builder: (data, refresh) => Text('Open issues: ${data['count']}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Temporary service failure'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Open issues: 4'), findsOneWidget);
    },
  );
  testWidgets(
    'admin order pages pass receipt dates and payment mode to the server and reset the cursor',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> load(Map<String, dynamic> p) async {
        requests.add(Map.from(p));
        return {
          'orders': <Map<String, dynamic>>[],
          'next': p['after'] == null ? 'next-order' : null,
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AdminOrdersScreen(
            initialPayment: 'paid',
            initialMode: 'manual',
            initialDateField: 'paidAt',
            initialDates: DateTimeRange(
              start: DateTime(2026, 10, 20),
              end: DateTime(2026, 10, 20),
            ),
            ordersLoader: load,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.last['mode'], 'manual');
      expect(requests.last['dateField'], 'paidAt');
      expect(
        requests.last['from'],
        DateTime.utc(2026, 10, 19, 16).millisecondsSinceEpoch,
      );
      expect(
        requests.last['to'],
        DateTime.utc(2026, 10, 20, 16).millisecondsSinceEpoch,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(requests.last['after'], 'next-order');
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(requests.last.containsKey('after'), false);
      await tester.ensureVisible(find.text('Clear filters'));
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(requests.last.containsKey('payment'), false);
      expect(requests.last.containsKey('mode'), false);
      expect(requests.last['dateField'], 'createdAt');
    },
  );
  testWidgets(
    'admin order cards and filters remain usable at 320 pixels with double text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
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
          home: AdminOrdersScreen(
            ordersLoader: (p) async => {
              'orders': [
                {
                  'id': 'long-order-reference',
                  'recipientName': 'Test customer with a long name',
                  'totalAmount': 23,
                  'orderStatus': 'Awaiting Customer Confirmation',
                  'paymentStatus': 'paid',
                  'orderMode': 'toyyibpay_sandbox',
                },
              ],
              'next': null,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
