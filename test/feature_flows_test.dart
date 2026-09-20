import 'package:bloom_and_bunch_kl/core/constants/fulfillment_constants.dart';
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/core/services/favourites_service.dart';
import 'package:bloom_and_bunch_kl/core/widgets/legal_documents.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/bouquet_detail_screen.dart';
import 'package:bloom_and_bunch_kl/models/bouquet_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeFavourites implements FavouritesService {
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> isBouquetFavourited(
    String id,
  ) => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<CartProvider> mount(
    WidgetTester tester, {
    String? mode,
    bool ready = true,
  }) async {
    final cart = CartProvider();
    final bouquet = BouquetModel(
      id: 'rose',
      name: 'Rose',
      description: 'Fresh roses',
      category: 'Birthday',
      imageUrl: '',
      price: 55,
      isPublished: true,
      availableForReadyNow: ready,
      readyStock: ready ? 5 : 0,
      availableForPreOrder: true,
      leadTimeBusinessDays: 2,
      recipeStems: {'rose': 12},
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(
          home: BouquetDetailScreen(
            bouquet: bouquet,
            initialFulfillmentType: mode,
            favouritesService: FakeFavourites(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cart;
  }

  testWidgets(
    'pre-order detail retains the selected mode for a dual-mode bouquet',
    (tester) async {
      final cart = await mount(tester, mode: FulfillmentTypes.preOrder);
      await tester.tap(find.text('Add to cart'));
      expect(cart.items.single.fulfillmentType, FulfillmentTypes.preOrder);
      expect(cart.items.single.leadTimeBusinessDays, 2);
    },
  );
  testWidgets(
    'pre-order-only favourite can be ordered through the details selector',
    (tester) async {
      final cart = await mount(tester, ready: false);
      await tester.tap(find.text('Add to cart'));
      expect(cart.items.single.fulfillmentType, FulfillmentTypes.preOrder);
    },
  );
  testWidgets('cart capacity failure does not show an added confirmation', (
    tester,
  ) async {
    final cart = await mount(tester);
    cart.addReadyMadeItem(
      bouquetId: 'rose',
      name: 'Rose',
      imageUrl: '',
      price: 55,
      quantity: 20,
    );
    await tester.tap(find.text('Add to cart'));
    await tester.pump();
    expect(cart.items.single.quantity, 20);
    expect(find.text('Maximum 20 bouquets per cart line.'), findsOneWidget);
    expect(find.text('Rose added to your cart.'), findsNothing);
  });
  testWidgets('policies are readable before signing in', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PolicyLinks())),
    );
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Firebase Authentication'), findsOneWidget);
    expect(find.textContaining('Add your actual'), findsNothing);
  });
}
