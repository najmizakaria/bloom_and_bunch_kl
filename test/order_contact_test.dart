import 'dart:async';
import 'package:bloom_and_bunch_kl/core/services/rider_contact_service.dart';
import 'package:bloom_and_bunch_kl/core/utils/malaysian_phone.dart';
import 'package:bloom_and_bunch_kl/features/support/order_contact_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Contacts extends RiderContactService {
  String? requested;
  bool fail = false;
  @override
  Future<RiderContact> getForOrder(String orderId) async {
    requested = orderId;
    if (fail) {
      throw StateError(
        'Rider contact is unavailable. Please call the florist.',
      );
    }
    return const RiderContact(name: 'Assigned Rider', phone: '+60123456789');
  }
}

class DelayedContact extends RiderContactService {
  final pending = Completer<RiderContact>();
  @override
  Future<RiderContact> getForOrder(String orderId) => pending.future;
}

void main() {
  testWidgets(
    'a reassignment while fetching never displays the former rider contact',
    (tester) async {
      final service = DelayedContact();
      var riderId = 'first';
      late StateSetter updateOrder;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, update) {
                updateOrder = update;
                return OrderContactActions(
                  orderId: 'order',
                  order: {
                    'orderStatus': 'Out for Delivery',
                    'riderId': riderId,
                  },
                  service: service,
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Call Rider'));
      await tester.pump();
      updateOrder(() => riderId = 'replacement');
      await tester.pump();
      service.pending.complete(
        const RiderContact(name: 'Former Rider', phone: '+60123456789'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Former Rider'), findsNothing);
      expect(find.textContaining('assignment changed'), findsOneWidget);
    },
  );
  test('application phone formats normalize to safe dialer numbers', () {
    for (final number in [
      '0123456789',
      '+60 12-345 6789',
      '60123456789',
      '0060123456789',
    ]) {
      expect(MalaysianPhone.normalize(number), '+60123456789');
    }
    for (final number in ['', 'abc', '123', '0123456789?body=bad']) {
      expect(() => MalaysianPhone.normalize(number), throwsFormatException);
    }
  });
  testWidgets(
    'before assignment the rider button is disabled and explains why',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrderContactActions(
              orderId: 'order',
              order: {'orderStatus': 'Ready for Delivery', 'riderId': null},
            ),
          ),
        ),
      );
      expect(find.text('Call Florist'), findsOneWidget);
      expect(find.text('Rider not assigned yet'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Call Rider'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'active order fetches its assigned contact then opens the correct dialer URI',
    (tester) async {
      final service = Contacts();
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderContactActions(
              orderId: 'specific-order',
              order: const {
                'orderStatus': 'Out for Delivery',
                'riderId': 'assigned',
              },
              service: service,
              open: (uri) async {
                opened = uri;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Call Rider'));
      await tester.pumpAndSettle();
      expect(service.requested, 'specific-order');
      expect(find.text('Assigned Rider'), findsOneWidget);
      expect(find.text('+60123456789'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Call Rider'));
      await tester.pumpAndSettle();
      expect(opened, Uri(scheme: 'tel', path: '+60123456789'));
    },
  );
  testWidgets('completed orders keep florist contact without rider calling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrderContactActions(
            orderId: 'order',
            order: {'orderStatus': 'Completed', 'riderId': 'assigned'},
          ),
        ),
      ),
    );
    expect(find.text('Call Florist'), findsOneWidget);
    expect(find.text('Call Rider'), findsNothing);
    expect(find.text('Rider not assigned yet'), findsNothing);
  });
  testWidgets(
    'unavailable rider contact exposes retry without displaying a phone number',
    (tester) async {
      final service = Contacts()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderContactActions(
              orderId: 'order',
              order: const {
                'orderStatus': 'Out for Delivery',
                'riderId': 'assigned',
              },
              service: service,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Call Rider'));
      await tester.pumpAndSettle();
      expect(
        find.text('Rider contact is unavailable. Please call the florist.'),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Call Rider'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'florist and rider choices have distinct numbers; missing dialer retains copyable contact',
    (tester) async {
      Uri? attempted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderContactActions(
              orderId: 'order',
              order: const {'orderStatus': 'Ready for Delivery'},
              open: (uri) async {
                attempted = uri;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Call Florist'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Call Florist'));
      await tester.pumpAndSettle();
      expect(attempted, Uri(scheme: 'tel', path: '+60148376919'));
      expect(find.text('+60148376919'), findsOneWidget);
      expect(find.textContaining('Copy the number'), findsOneWidget);
    },
  );
}
