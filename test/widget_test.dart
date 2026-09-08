import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/models/flower_model.dart';
import 'package:bloom_and_bunch_kl/models/order_model.dart';

void main() {
  test('same bouquet keeps urgent and preorder lines separate', () {
    final c = CartProvider();
    c.addReadyMadeItem(bouquetId: 'a', name: 'A', imageUrl: '', price: 50);
    c.addReadyMadeItem(
      bouquetId: 'a',
      name: 'A',
      imageUrl: '',
      price: 50,
      fulfillmentType: 'pre_order',
      leadTimeBusinessDays: 3,
    );
    expect(c.items.length, 2);
    expect(c.totalPrice, 100);
  });
  test('retry ID stays stable until cart changes', () {
    final c = CartProvider();
    final id = c.checkoutId;
    expect(c.checkoutId, id);
    c.addReadyMadeItem(bouquetId: 'a', name: 'A', imageUrl: '', price: 1);
    expect(c.checkoutId, isNot(id));
  });
  test('custom stems snapshot cannot be changed by caller', () {
    final stems = {'rose': 100};
    final c = CartProvider();
    c.addCustomItem(
      unitPrice: 300,
      stems: stems,
      wrapper: 'Kraft Paper (Classic)',
      ribbon: 'Red Satin',
      cardNote: '',
    );
    stems['rose'] = 1;
    expect(c.items.single.customStems!['rose'], 100);
    expect(c.items.single.fulfillmentType, 'custom');
  });
  test('legacy zero-stock flower remains sourceable, shortages internal', () {
    final f = FlowerModel.fromMap({
      'name': 'Rose',
      'stockQuantity': 0,
      'reservedQuantity': 100,
      'isAvailable': false,
    }, 'r');
    expect(f.availableForCustomOrder, true);
    expect(f.projectedBalance, -100);
    expect(f.shortageQuantity, 100);
  });
  test('legacy order statuses remain readable', () {
    expect(
      OrderModel.fromMap({'orderStatus': 'Pending'}, 'a').orderStatus,
      'Awaiting Preparation',
    );
    expect(
      OrderModel.fromMap({'orderStatus': 'Completed'}, 'a').orderStatus,
      'Delivered',
    );
  });
}
