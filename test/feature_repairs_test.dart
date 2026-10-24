import 'dart:typed_data';
import 'package:bloom_and_bunch_kl/core/services/reorder_service.dart';
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/core/constants/fulfillment_constants.dart';
import 'package:bloom_and_bunch_kl/core/services/product_image.dart';
import 'package:bloom_and_bunch_kl/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  bool add(CartProvider cart, {int quantity = 3}) => cart.addReadyMadeItem(
    bouquetId: 'rose',
    name: 'Rose',
    imageUrl: '',
    price: 0.333,
    quantity: quantity,
    fulfillmentType: FulfillmentTypes.preOrder,
    leadTimeBusinessDays: 2,
  );
  test(
    'cart restores quantities, fulfilment and checkout ID after restart',
    () async {
      final first = CartProvider();
      await first.switchUser('alice');
      expect(add(first), true);
      await first.flush();
      final restored = CartProvider();
      await restored.switchUser('alice');
      expect(restored.items.single.quantity, 3);
      expect(restored.items.single.fulfillmentType, FulfillmentTypes.preOrder);
      expect(restored.checkoutId, first.checkoutId);
      expect(restored.totalPrice, 0.99);
    },
  );
  test(
    'uncertain checkout persists its exact request and blocks cart edits',
    () async {
      final first = CartProvider();
      await first.switchUser('alice');
      add(first);
      final request = {
        'checkoutId': first.checkoutId,
        'address': {'address': 'Confirmed'},
        'items': first.items.map((i) => i.toMap()).toList(),
      };
      await first.prepareCheckout(request);
      request['address'] = {'address': 'Changed'};
      expect(add(first), false);
      final restored = CartProvider();
      await restored.switchUser('alice');
      expect(restored.hasPendingCheckout, true);
      expect(
        (restored.pendingRequest!['address'] as Map)['address'],
        'Confirmed',
      );
      expect(
        await restored.prepareCheckout({'address': 'Different'}),
        first.pendingRequest,
      );
      restored.checkoutRejected();
      expect(add(restored), true);
      restored.checkoutSucceeded();
      await restored.flush();
      final completed = CartProvider();
      await completed.switchUser('alice');
      expect(completed.isEmpty, true);
      expect(completed.hasPendingCheckout, false);
    },
  );
  test(
    'switching accounts isolates carts and signing out retains own cart',
    () async {
      final cart = CartProvider();
      await cart.switchUser('alice');
      add(cart);
      await cart.switchUser('bob');
      expect(cart.isEmpty, true);
      add(cart, quantity: 1);
      await cart.switchUser(null);
      expect(cart.isEmpty, true);
      await cart.switchUser('alice');
      expect(cart.items.single.quantity, 3);
      await cart.switchUser('bob');
      expect(cart.items.single.quantity, 1);
    },
  );
  test('account deletion forgets local cart and pending checkout', () async {
    final cart = CartProvider();
    await cart.switchUser('alice');
    add(cart);
    await cart.prepareCheckout({'checkoutId': cart.checkoutId});
    await cart.switchUser(null);
    await cart.forgetDeletedUser('alice');
    final restored = CartProvider();
    await restored.switchUser('alice');
    expect(restored.isEmpty, true);
    expect(restored.pendingRequest, null);
  });
  test('Delivered, legacy Completed and Cancelled belong to past orders', () {
    for (final status in ['Delivered', 'Completed', 'Cancelled']) {
      expect(OrderStatuses.isPast(status), true);
    }
    for (final status in [
      'Processing',
      'Out for Delivery',
      'Ready for Delivery',
    ]) {
      expect(OrderStatuses.isPast(status), false);
    }
  });
  test('whole custom bouquet is rounded once, cart totals use integer sen', () {
    expect(Money.customTotal([0.333 * 3], 7), 8);
    expect(Money.round(7 + 0.333 * 3), 8);
  });
  test('product image validates actual bytes and upload size', () {
    final png = ProductImage.fromBytes(
      Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    expect(png.contentType, 'image/png');
    expect(png.extension, 'png');
    expect(
      () => ProductImage.fromBytes(Uint8List.fromList('<script>'.codeUnits)),
      throwsStateError,
    );
    expect(
      () => ProductImage.fromBytes(Uint8List(ProductImage.maximumBytes + 1)),
      throwsStateError,
    );
  });
  test(
    'order again restores original pre-order quantity at the current price',
    () async {
      final cart = CartProvider();
      await ReorderService.add(
        cart,
        {'bouquetId': 'rose', 'fulfillmentType': 'pre_order', 'quantity': 3},
        readDocument: (collection, id) async => {
          'name': 'Rose',
          'description': '',
          'category': 'Birthday',
          'imageUrl': '',
          'price': 55,
          'isPublished': true,
          'readyStock': 0,
          'availableForReadyNow': false,
          'availableForPreOrder': true,
          'recipeStems': {'rose': 12},
          'leadTimeBusinessDays': 2,
        },
      );
      expect(cart.items.single.quantity, 3);
      expect(cart.items.single.fulfillmentType, 'pre_order');
      expect(cart.totalPrice, 165);
    },
  );
  test(
    'custom reorder preserves quantity and reprices fractional stems once',
    () async {
      final cart = CartProvider();
      await ReorderService.add(
        cart,
        {
          'fulfillmentType': 'custom',
          'quantity': 2,
          'customStems': {'rose': 3},
          'wrapper': 'Kraft Paper (Classic)',
          'ribbon': 'Red Satin',
        },
        readDocument: (collection, id) async => {
          'name': 'Rose',
          'pricePerStem': 0.333,
          'availableForCustomOrder': true,
        },
      );
      expect(cart.items.single.quantity, 2);
      expect(cart.items.single.unitPrice, 8);
      expect(cart.totalPrice, 16);
    },
  );
  test(
    'unavailable reorder leaves cart unchanged; later available items can be added',
    () async {
      final cart = CartProvider();
      expect(
        ReorderService.add(cart, {
          'bouquetId': 'gone',
        }, readDocument: (collection, id) async => null),
        throwsStateError,
      );
      expect(cart.isEmpty, true);
      expect(add(cart), true);
      expect(cart.items.single.quantity, 3);
    },
  );
  test('late sign-out cannot recreate a deleted account cart', () async {
    final cart = CartProvider();
    await cart.switchUser('alice');
    add(cart);
    await cart.forgetDeletedUser('alice');
    await cart.switchUser(null);
    await cart.flush();
    final restored = CartProvider();
    await restored.switchUser('alice');
    expect(restored.isEmpty, true);
  });
}
