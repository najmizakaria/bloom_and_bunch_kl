// Audit-only regression checks for unfixed defects. Run explicitly.
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('REGRESSION: cart respects backend maximum 20 per line', () {
    final cart = CartProvider();
    cart.addReadyMadeItem(
      bouquetId: 'audit',
      name: 'Audit',
      imageUrl: '',
      price: 50,
    );
    for (var i = 0; i < 20; i++) {
      cart.incrementQuantity(cart.items.single.id);
    }
    expect(cart.items.single.quantity, lessThanOrEqualTo(20));
  });
  test('REGRESSION: cart respects backend maximum 20 distinct lines', () {
    final cart = CartProvider();
    for (var i = 0; i < 21; i++) {
      cart.addReadyMadeItem(
        bouquetId: 'audit_$i',
        name: 'Audit',
        imageUrl: '',
        price: 50,
      );
    }
    expect(cart.items.length, lessThanOrEqualTo(20));
  });
}
