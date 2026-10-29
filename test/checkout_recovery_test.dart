import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/core/services/address_service.dart';
import 'package:bloom_and_bunch_kl/core/services/checkout_service.dart';
import 'package:bloom_and_bunch_kl/core/services/order_service.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/checkout_screen.dart';
import 'package:bloom_and_bunch_kl/models/cart_item_model.dart';
import 'package:bloom_and_bunch_kl/models/saved_address_model.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const address = SavedAddressModel(
  id: 'home',
  label: 'Home',
  address: 'KL',
  recipientName: 'Recipient',
  recipientPhone: '0123456789',
  note: '',
  latitude: 3.139,
  longitude: 101.687,
);

class Addresses implements AddressService {
  @override
  Future<SavedAddressModel?> defaultAddress() async => address;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Quotes implements CheckoutService {
  int calls = 0;
  @override
  Future<CheckoutQuote> quote(
    List<CartItemModel> items,
    SavedAddressModel address,
  ) async {
    calls++;
    return CheckoutQuote({
      'quoteId': 'quote-$calls',
      'mode': 'demo',
      'totalSen': 5000,
      'subtotalSen': 5000,
      'deliveryFeeSen': 0,
      'groups': [],
      'paymentInstructions': 'No payment.',
      'timingNotice': 'Demo only.',
    });
  }
}

class UnavailableQuotes implements CheckoutService {
  @override
  Future<CheckoutQuote> quote(
    List<CartItemModel> items,
    SavedAddressModel address,
  ) async => throw FirebaseFunctionsException(
    code: 'not-found',
    message: 'Missing service',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UncertainOrders implements OrderService {
  final List<Map<String, dynamic>> requests = [];
  @override
  Future<List<String>> placeOrder(Map<String, dynamic> request) async {
    requests.add(request);
    throw FirebaseFunctionsException(
      code: 'unavailable',
      message: 'Network interrupted',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'missing quote disables ordering without displaying a zero total',
    (tester) async {
      final cart = CartProvider();
      await cart.switchUser('buyer');
      cart.addReadyMadeItem(
        bouquetId: 'rose',
        name: 'Rose',
        imageUrl: '',
        price: 50,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: MaterialApp(
            home: CheckoutScreen(
              addressService: Addresses(),
              checkoutService: UnavailableQuotes(),
              orderService: UncertainOrders(),
              currentUserId: () => 'buyer',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('confirm-order')),
        200,
      );
      expect(find.text('Order summary unavailable'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirm-order')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('RM 0.00'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      cart.dispose();
    },
  );
  testWidgets(
    'uncertain checkout survives screen reload and reuses exact quote and request',
    (tester) async {
      final cart = CartProvider();
      await cart.switchUser('buyer');
      cart.addReadyMadeItem(
        bouquetId: 'rose',
        name: 'Rose',
        imageUrl: '',
        price: 50,
      );
      final quotes = Quotes(), orders = UncertainOrders();
      Future<void> mount() async {
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: cart,
            child: MaterialApp(
              home: CheckoutScreen(
                addressService: Addresses(),
                checkoutService: quotes,
                orderService: orders,
                currentUserId: () => 'buyer',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount();
      await tester.scrollUntilVisible(
        find.byKey(const Key('confirm-order')),
        200,
      );
      await tester.tap(find.byKey(const Key('confirm-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(orders.requests, isEmpty);
      expect(cart.hasPendingCheckout, isFalse);
      await tester.scrollUntilVisible(
        find.byKey(const Key('confirm-order')),
        200,
      );
      await tester.tap(find.byKey(const Key('confirm-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm order'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('confirm-order')),
        200,
      );
      await tester.pumpAndSettle();
      expect(cart.hasPendingCheckout, isTrue);
      expect(find.text('Check existing order'), findsOneWidget);
      expect(quotes.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await mount();
      await tester.scrollUntilVisible(
        find.byKey(const Key('confirm-order')),
        200,
      );
      await tester.tap(find.byKey(const Key('confirm-order')));
      await tester.pumpAndSettle();
      expect(orders.requests.length, 2);
      expect(orders.requests[1], orders.requests[0]);
      expect(quotes.calls, 1);
      expect(cart.items.single.quantity, 1);
    },
  );
}
