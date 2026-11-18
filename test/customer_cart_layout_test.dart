import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/cart_screen.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets(
      'cart summary and checkout remain reachable at $size with double text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cart = CartProvider();
        cart.addReadyMadeItem(
          bouquetId: 'layout',
          name: 'Birthday bouquet',
          imageUrl: '',
          price: 50,
          quantity: 2,
        );
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: cart,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: const CartScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Cart'), findsOneWidget);
        expect(find.text('Order Summary'), findsOneWidget);
        expect(find.text('Subtotal for products'), findsOneWidget);
        expect(find.text('Free'), findsOneWidget);
        final label = find.text('Total');
        final price = find.text('RM 100.00').last;
        expect(
          tester.getCenter(label).dx,
          lessThan(tester.getCenter(price).dx),
        );
        await tester.ensureVisible(find.text('Checkout'));
        await tester.pumpAndSettle();
        expect(find.text('Checkout').hitTestable(), findsOneWidget);
        cart.dispose();
      },
    );
  }

  testWidgets('swiping reveals Remove without removing the bouquet', (
    tester,
  ) async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    cart.addReadyMadeItem(
      bouquetId: 'swipe',
      name: 'Bouquet to remove',
      imageUrl: '',
      price: 50,
      quantity: 1,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: const MaterialApp(home: CartScreen()),
      ),
    );
    final remove = find.byTooltip('Remove');
    final name = find.text('Bouquet to remove');
    final card = find.ancestor(of: name, matching: find.byType(Card)).first;
    final center = tester.getCenter(card).dy;
    expect(tester.getCenter(find.byTooltip('Decrease quantity')).dy, center);
    expect(tester.getCenter(find.text('1')).dy, center);
    expect(tester.getCenter(find.byTooltip('Increase quantity')).dy, center);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(remove, findsNothing);
    await tester.drag(name, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(cart.itemCount, 1);
    expect(remove.hitTestable(), findsOneWidget);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(cart.isEmpty, isTrue);
  });
}
