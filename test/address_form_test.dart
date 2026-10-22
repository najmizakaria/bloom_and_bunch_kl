import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bloom_and_bunch_kl/core/services/address_service.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/address_book_screen.dart';
import 'package:bloom_and_bunch_kl/models/saved_address_model.dart';

class TestAddresses implements AddressService {
  final saved = <SavedAddressModel>[];
  int ids = 0;
  Object? nextError;
  @override
  String newAddressId() {
    ids++;
    return 'new_address';
  }

  @override
  Future<String> saveAddress(SavedAddressModel address) async {
    saved.add(address);
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
    return address.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    await tester.scrollUntilVisible(
      field,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(field, value);
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Save address'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Save address').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'required labels block blank input and pin changes preserve typed full address',
    (tester) async {
      final service = TestAddresses();
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryAddressFormScreen(
            service: service,
            detectLocationOnOpen: false,
            selectPin: (_, _) async => const LatLng(3.2, 101.7),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Full address *'), findsOneWidget);
      expect(find.text('Delivery note (optional)'), findsOneWidget);
      await tapSave(tester);
      expect(service.saved, isEmpty);
      expect(find.text('Required'), findsWidgets);
      await fill(
        tester,
        'Full address *',
        'Unit 2, manually entered full address',
      );
      await fill(tester, 'Recipient name *', 'Test recipient');
      await fill(tester, 'Phone *', '0123456789');
      await tester.scrollUntilVisible(
        find.text('Confirm delivery pin *'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm delivery pin *'));
      await tester.pumpAndSettle();
      expect(find.text('Review delivery pin'), findsOneWidget);
      final addressField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Full address *',
        ),
      );
      expect(
        addressField.controller!.text,
        'Unit 2, manually entered full address',
      );
    },
  );
  testWidgets(
    'failed save keeps details and retry uses same address ID then returns saved address',
    (tester) async {
      final service = TestAddresses()
        ..nextError = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Offline',
        );
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Address list')),
        ),
      );
      final result = navigator.currentState!.push<SavedAddressModel>(
        MaterialPageRoute(
          builder: (_) => DeliveryAddressFormScreen(
            service: service,
            detectLocationOnOpen: false,
            selectPin: (_, _) async => const LatLng(3.139, 101.687),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await fill(tester, 'Full address *', '12 Test Street, Kuala Lumpur');
      await fill(tester, 'Town / City *', 'Kuala Lumpur');
      await fill(tester, 'Postcode *', '50000');
      await fill(tester, 'State / Federal territory *', 'Kuala Lumpur');
      await fill(tester, 'Recipient name *', 'Test recipient');
      await fill(tester, 'Phone *', '0123456789');
      await tapSave(tester);
      expect(find.textContaining('Your details are kept here'), findsOneWidget);
      expect(service.saved.single.address, '12 Test Street, Kuala Lumpur');
      await tapSave(tester);
      final saved = await result;
      expect(saved!.id, 'new_address');
      expect(saved.address, '12 Test Street, Kuala Lumpur');
      expect(saved.locality, 'Kuala Lumpur');
      expect(saved.postcode, '50000');
      expect(saved.state, 'Kuala Lumpur');
      expect(service.ids, 1);
      expect(service.saved.map((a) => a.id).toSet(), {'new_address'});
      expect(find.text('Address list'), findsOneWidget);
    },
  );
  test(
    'missing address service has an actionable address-specific message',
    () {
      expect(
        AddressService.message(
          FirebaseFunctionsException(code: 'not-found', message: 'Missing'),
        ),
        contains('address service is unavailable'),
      );
      expect(
        AddressService.message(
          FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'Signed out',
          ),
        ),
        contains('sign in again'),
      );
    },
  );
}
