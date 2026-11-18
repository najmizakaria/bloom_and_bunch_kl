import 'package:bloom_and_bunch_kl/core/constants/fulfillment_constants.dart';
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/core/services/favourites_service.dart';
import 'package:bloom_and_bunch_kl/core/widgets/legal_documents.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/bouquet_detail_screen.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/bouquet_options_screen.dart';
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

class AddonCatalogue extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  AddonCatalogue(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

// ignore: subtype_of_sealed_class
class ChocolateAddon extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  static const name = 'Ferrero Rocher Chocolate (24 pcs)';

  @override
  String get id => 'chocolate';

  @override
  Map<String, dynamic> data() => {
    'name': name,
    'price': 30,
    'stockQuantity': 2,
  };
}

void main() {
  Future<CartProvider> mount(
    WidgetTester tester, {
    String? mode,
    bool ready = true,
    bool preOrder = true,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> addons = const [],
    String? Function()? selectDate,
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
      availableForPreOrder: preOrder,
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
            optionsBuilder: (draft) => BouquetOptionsScreen(
              bouquet: draft,
              catalogueStream: Stream.value(AddonCatalogue(addons)),
              datePicker: (_, items) async =>
                  selectDate == null ? '2026-11-12' : selectDate(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cart;
  }

  testWidgets('add-on quantity controls fit beside a long name on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await mount(tester, addons: [ChocolateAddon()]);
    await tester.tap(find.text('Choose add-ons'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ready to send'));
    await tester.pumpAndSettle();

    final name = find.text(ChocolateAddon.name);
    final add = find.byTooltip('Add one');
    final remove = find.byTooltip('Remove one');
    expect(tester.widget<Text>(name).maxLines, 2);
    final rowCenter = tester.getCenter(add).dy;
    expect(tester.getCenter(remove).dy, rowCenter);
    expect(tester.getCenter(find.text('0')).dy, rowCenter);
    expect(tester.getTopLeft(name).dy, lessThan(rowCenter));
    await tester.tap(add);
    await tester.pump();
    expect(tester.getCenter(find.text('1')).dy, tester.getCenter(add).dy);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pre-order section opens add-ons directly for a dual-mode bouquet',
    (tester) async {
      var dateRequests = 0;
      final cart = await mount(
        tester,
        mode: FulfillmentTypes.preOrder,
        selectDate: () {
          dateRequests++;
          return '2026-11-12';
        },
      );
      final summary = find.text('Fresh roses');
      await tester.scrollUntilVisible(summary, 150);
      expect(
        tester.getTopLeft(summary).dy,
        greaterThan(tester.getBottomLeft(find.text('RM 55.00')).dy),
      );
      expect(find.text('Pre-order'), findsNothing);
      await tester.tap(find.text('Choose add-ons'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a delivery option'), findsNothing);
      expect(cart.isEmpty, true);
      expect(dateRequests, 0);
      await tester.tap(find.text('Add to cart'));
      await tester.pumpAndSettle();
      expect(dateRequests, 1);
      expect(
        cart.items.single.toMap(),
        containsPair('fulfillmentType', FulfillmentTypes.preOrder),
      );
      expect(
        cart.items.single.toMap(),
        containsPair('leadTimeBusinessDays', 2),
      );
      expect(
        cart.items.single.toMap(),
        containsPair('requestedDeliveryDate', '2026-11-12'),
      );
    },
  );
  testWidgets('ready-to-send section offers both valid modes', (tester) async {
    final cart = await mount(tester, mode: FulfillmentTypes.readyNow);
    await tester.tap(find.text('Choose add-ons'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a delivery option'), findsOneWidget);
    expect(find.text('Ready to send'), findsOneWidget);
    await tester.tap(find.text('Pre-order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    expect(cart.items.single.fulfillmentType, FulfillmentTypes.preOrder);
    expect(cart.items.single.requestedDeliveryDate, '2026-11-12');
  });
  testWidgets('a ready-only bouquet skips the chooser and date picker', (
    tester,
  ) async {
    final cart = await mount(
      tester,
      mode: FulfillmentTypes.readyNow,
      preOrder: false,
      selectDate: () => throw StateError('Ready-to-send needs no date'),
    );
    await tester.tap(find.text('Choose add-ons'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a delivery option'), findsNothing);
    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    expect(cart.items.single.fulfillmentType, FulfillmentTypes.readyNow);
    expect(cart.items.single.leadTimeBusinessDays, 0);
    expect(cart.items.single.requestedDeliveryDate, isNull);
  });
  testWidgets(
    'pre-order-only favourite stays on add-ons when the date picker is cancelled',
    (tester) async {
      String? date;
      final cart = await mount(tester, ready: false, selectDate: () => date);
      await tester.tap(find.text('Choose add-ons & date'));
      await tester.pumpAndSettle();
      final add = find.text('Add to cart');
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(cart.isEmpty, true);
      expect(add, findsOneWidget);
      date = '2026-11-12';
      await tester.tap(add);
      await tester.pumpAndSettle();
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
    await tester.tap(find.text('Choose add-ons'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ready to send'));
    await tester.pumpAndSettle();
    expect(find.text('Deliver later (optional)'), findsNothing);
    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
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
