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
          quantity: 1,
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
        expect(find.text('Items subtotal'), findsOneWidget);
        await tester.ensureVisible(find.text('Proceed to Checkout'));
        await tester.pumpAndSettle();
        expect(find.text('Proceed to Checkout').hitTestable(), findsOneWidget);
        cart.dispose();
      },
    );
  }
}
