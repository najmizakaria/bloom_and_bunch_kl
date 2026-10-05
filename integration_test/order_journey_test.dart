import 'package:bloom_and_bunch_kl/core/services/favourites_service.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/become_rider_screen.dart';
import 'package:bloom_and_bunch_kl/features/auth/screens/auth_gate.dart';
import 'package:bloom_and_bunch_kl/features/admin/rider_history_screen.dart';
import 'package:bloom_and_bunch_kl/core/config/app_environment.dart';
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/bouquet_detail_screen.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/cart_screen.dart';
import 'package:bloom_and_bunch_kl/models/order_model.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/bouquet_builder_screen.dart';
import 'package:bloom_and_bunch_kl/features/rider/screens/rider_order_detail_screen.dart';
import 'package:bloom_and_bunch_kl/features/support/store_operations_screen.dart';
import 'package:bloom_and_bunch_kl/models/bouquet_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/main_navigation_screen.dart';
import 'package:bloom_and_bunch_kl/features/florist/screens/florist_main_navigation_screen.dart';
import 'package:bloom_and_bunch_kl/features/florist/screens/florist_dashboard_screen.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_main_screen.dart';
import 'package:bloom_and_bunch_kl/features/rider/screens/rider_home_screen.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/order_tracking_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const focus = String.fromEnvironment('JOURNEY_FILTER');
  setUpAll(() async {
    expect(AppEnvironment.isDemo, isTrue);
    await AppEnvironment.initialize();
  });
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 300 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(finder, findsWidgets);
  }

  testWidgets('real callable checkout, rider delivery and owner feedback', (
    tester,
  ) async {
    expect(
      AppEnvironment.isDemo,
      isTrue,
      reason: 'Run only with APP_ENV=demo.',
    );
    await AppEnvironment.initialize();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'customer@demo.bloom.test',
      password: 'DemoPass123!',
    );
    final db = FirebaseFirestore.instance;
    final product = await db.doc('bouquets/demo_bouquet').get();
    final stock = product.data()!['readyStock'] as int;
    final cart = CartProvider();
    await cart.switchUser('demo_customer');
    cart.clear();
    await cart.flush();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(
          home: BouquetDetailScreen(
            bouquet: BouquetModel.fromMap(product.data()!, product.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    expect(cart.items.single.quantity, 1);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: const MaterialApp(key: Key('cart-journey'), home: CartScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Proceed to Checkout'));
    await tester.pumpAndSettle();
    expect(find.text('Proceed to Checkout').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Proceed to Checkout'));
    await tester.pumpAndSettle();
    expect(
      find.text('Review your order'),
      findsOneWidget,
      reason:
          'Visible texts: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(" | ")}',
    );
    await waitFor(
      tester,
      find.text('Demo order — no payment or real delivery'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('confirm-order')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Stream/network progress does not always settle; wait for a concrete ready state.
    for (
      var i = 0;
      i < 150 && !find.text('Place demo order').evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Place demo order'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('confirm-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm order'));
    await waitFor(tester, find.text('Track order'));
    for (
      var i = 0;
      i < 150 && find.text('Track order').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Track order'), findsOneWidget);
    final orders = await db
        .collection('orders')
        .where('customerId', isEqualTo: 'demo_customer')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    final order = orders.docs.single;
    expect(order.data()['totalAmount'], 50);
    expect(order.data()['orderMode'], 'demo');
    expect(
      (await db.doc('bouquets/demo_bouquet').get()).data()!['readyStock'],
      stock - 1,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'rider@demo.bloom.test',
      password: 'DemoPass123!',
    );
    await tester.pumpWidget(const MaterialApp(home: RiderHomeScreen()));
    await waitFor(tester, find.text('Kuala Lumpur'));
    await tester.tap(find.widgetWithText(ListTile, 'Kuala Lumpur').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept Delivery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept delivery').last);
    await waitFor(tester, find.text('Delivery workspace'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 150; i++) {
      if (tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex ==
          1) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect((await order.reference.get()).data()!['riderId'], 'demo_rider');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    // Exercise operational exceptions through the actual customer/staff UI.
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'customer@demo.bloom.test',
      password: 'DemoPass123!',
    );
    await tester.pumpWidget(
      MaterialApp(
        key: const Key('issue-customer'),
        home: OrderTrackingScreen(orderId: order.id),
      ),
    );
    await waitFor(tester, find.text('Report a problem'));
    await tester.scrollUntilVisible(find.text('Report a problem'), 200);
    await tester.tap(find.text('Report a problem'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Please verify the handover.',
    );
    await tester.tap(find.text('Send to store'));
    await waitFor(tester, find.text('Your issue is awaiting store review'));
    expect((await order.reference.get()).data()!['support']['status'], 'open');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'admin@demo.bloom.test',
      password: 'DemoPass123!',
    );
    await tester.pumpWidget(
      const MaterialApp(key: Key('issue-admin'), home: StoreOperationsScreen()),
    );
    await waitFor(tester, find.text('Respond and resolve'));
    await tester.tap(find.text('Respond and resolve'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Handover checked with recipient.',
    );
    await tester.tap(find.text('Resolve issue'));
    await waitFor(tester, find.text('No orders in this queue.'));
    expect(
      (await order.reference.get()).data()!['orderStatus'],
      'Out for Delivery',
    );
    expect((await order.reference.collection('issues').get()).size, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'rider@demo.bloom.test',
      password: 'DemoPass123!',
    );
    final deliveryNavigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        key: const Key('delivery-ui'),
        navigatorKey: deliveryNavigator,
        home: const Scaffold(body: Text('Rider test root')),
      ),
    );
    await tester.pumpAndSettle();
    final awaitedOrderData = (await order.reference.get()).data()!;
    deliveryNavigator.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => RiderOrderDetailScreen(
          order: OrderModel.fromMap(awaitedOrderData, order.id),
        ),
      ),
    );
    await waitFor(tester, find.text('Mark as Delivered'));
    await tester.tap(find.text('Mark as Delivered'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm delivered'));
    await waitFor(tester, find.text('Rider test root'));
    await tester.pumpAndSettle();
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'customer@demo.bloom.test',
      password: 'DemoPass123!',
    );
    expect(
      (await order.reference.get()).data()!['orderStatus'],
      'Awaiting Customer Confirmation',
    );
    await tester.pumpWidget(
      MaterialApp(home: OrderTrackingScreen(orderId: order.id)),
    );
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('Delivered — awaiting your confirmation'));
    await tester.scrollUntilVisible(find.text('Confirm received'), 200);
    await tester.tap(find.text('Confirm received'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm received').last);
    await tester.pumpAndSettle();
    expect((await order.reference.get()).data()!['orderStatus'], 'Completed');
    await waitFor(tester, find.text('Send feedback'));
    await tester.scrollUntilVisible(
      find.text('Send feedback'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.ensureVisible(find.text('Send feedback'));
    await tester.pumpAndSettle();
    expect(find.text('Send feedback').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Send feedback'));
    await waitFor(tester, find.text('Thank you. Your rating: 5/5.'));
    expect((await order.reference.get()).data()!['feedback']['rating'], 5);
    await FirebaseAuth.instance.signOut();
    cart.dispose();
  }, skip: focus.isNotEmpty && focus != 'checkout');
  testWidgets(
    'customer Browse keeps navigation, florist cards choose filters and all roles expose More',
    (tester) async {
      final auth = FirebaseAuth.instance;
      Future<void> login(String role) => auth.signInWithEmailAndPassword(
        email: '$role@demo.bloom.test',
        password: 'DemoPass123!',
      );
      await login('customer');
      final cart = CartProvider();
      await cart.switchUser('demo_customer');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: const MaterialApp(home: MainNavigationScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('📅 Pre-Order'));
      await waitFor(tester, find.text('Late planned bouquet'));
      expect(find.text('Ready only 0'), findsNothing);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await waitFor(tester, find.text('Late planned bouquet'));
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Pre-Order'))
            .selected,
        isTrue,
      );
      expect(find.text('Ready only 0'), findsNothing);
      expect(find.text('Ready to send'), findsNothing);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await auth.signOut();
      await login('florist');
      await tester.pumpWidget(
        const MaterialApp(home: FloristMainNavigationScreen()),
      );
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('Latest 100 orders'));
      final preparingCard = find
          .ancestor(
            of: find.descendant(
              of: find.byType(FloristDashboardScreen),
              matching: find.text('Preparing'),
            ),
            matching: find.byType(InkWell),
          )
          .first;
      await tester.scrollUntilVisible(
        preparingCard,
        200,
        scrollable: find
            .descendant(
              of: find.byType(FloristDashboardScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(preparingCard);
      await tester.pumpAndSettle();
      expect(preparingCard.hitTestable(), findsOneWidget);
      final preparingCentre = tester.getCenter(preparingCard);
      await tester.tap(preparingCard);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
        reason:
            'Card tapped at $preparingCentre; view ${tester.view.physicalSize}',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Preparing'))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      final newCard = find
          .ancestor(
            of: find.descendant(
              of: find.byType(FloristDashboardScreen),
              matching: find.text('New'),
            ),
            matching: find.byType(InkWell),
          )
          .first;
      await tester.scrollUntilVisible(
        newCard,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(newCard);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'New'))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      final stockCard = find
          .ancestor(
            of: find.descendant(
              of: find.byType(FloristDashboardScreen),
              matching: find.text('Low Stock (preview)'),
            ),
            matching: find.byType(InkWell),
          )
          .first;
      await tester.scrollUntilVisible(
        stockCard,
        200,
        scrollable: find
            .descendant(
              of: find.byType(FloristDashboardScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(stockCard);
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('Inventory fixture 0'));
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
      expect(find.text('Page 1'), findsWidgets);
      await tester.tap(find.text('Next').hitTestable());
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('Page 2'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await auth.signOut();
      await login('admin');
      await tester.pumpWidget(const MaterialApp(home: AdminMainScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rider history'));
      await waitFor(tester, find.textContaining('Customer confirmed receipt:'));
      for (
        var i = 0;
        i < 150 &&
            find
                .textContaining('Customer confirmed receipt:')
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Customer confirmed receipt: '), findsNothing);
      expect(find.textContaining('Customer confirmed receipt:'), findsWidgets);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Log out'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await auth.signOut();
      await login('rider');
      await tester.pumpWidget(const MaterialApp(home: RiderHomeScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.logout), findsNothing);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Log out'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
      expect(find.byType(TabBar), findsNothing);
      await tester.tap(find.byTooltip('Back to home'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      await tester.tap(find.byTooltip('Back to home'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await auth.signOut();
      cart.dispose();
    },
    skip: focus.isNotEmpty && focus != 'navigation',
  );
  testWidgets(
    'authorized mixed-delivery links, responsive admin filters and approved role route reset',
    (tester) async {
      final auth = FirebaseAuth.instance;
      Future<void> login(String role) => auth.signInWithEmailAndPassword(
        email: '$role@demo.bloom.test',
        password: 'DemoPass123!',
      );
      for (final role in ['customer', 'admin']) {
        await login(role);
        if (role == 'customer') {
          Future<void> toggle() => FavouritesService().toggleBouquetFavourite(
            bouquetId: 'demo_bouquet',
            name: 'Demo Birthday Bouquet',
            imageUrl: '',
            price: 50,
          );
          await Future.wait([toggle(), toggle()]);
          expect(
            (await FirebaseFirestore.instance
                    .doc('users/demo_customer/favourite_bouquets/demo_bouquet')
                    .get())
                .exists,
            isTrue,
          );
          await toggle();
          expect(
            (await FirebaseFirestore.instance
                    .doc('users/demo_customer/favourite_bouquets/demo_bouquet')
                    .get())
                .exists,
            isFalse,
          );
        }
        await tester.pumpWidget(
          const MaterialApp(
            home: OrderTrackingScreen(orderId: 'fixture_mixed_ready'),
          ),
        );
        await waitFor(
          tester,
          find.text('Track your other delivery · Completed'),
        );
        expect(find.text('Completed (legacy record)'), findsOneWidget);
        await tester.ensureVisible(
          find.text('Track your other delivery · Completed'),
        );
        await tester.tap(find.text('Track your other delivery · Completed'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OrderTrackingScreen>(find.byType(OrderTrackingScreen))
              .orderId,
          'fixture_mixed_planned',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await auth.signOut();
      }
      await login('admin');
      final layoutErrors = <String>[];
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        layoutErrors.add(details.toString());
        previousErrorHandler?.call(details);
      };
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const RiderHistoryScreen(),
        ),
      );
      await waitFor(tester, find.text('Page 1'));
      await tester.pumpAndSettle();
      FlutterError.onError = previousErrorHandler;
      expect(tester.takeException(), isNull, reason: layoutErrors.join('\n'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await auth.signOut();
      await login('customer');
      final cart = CartProvider();
      await cart.switchUser('demo_customer');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: MaterialApp(
            key: const Key('role-journey'),
            navigatorKey: navigator,
            home: const AuthGate(),
          ),
        ),
      );
      await waitFor(tester, find.byType(MainNavigationScreen));
      final closed = navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const BecomeRiderScreen()),
      );
      await waitFor(tester, find.text('Switch to Rider Dashboard'));
      await tester.tap(find.text('Switch to Rider Dashboard'));
      await waitFor(tester, find.text('Delivery workspace'));
      await closed;
      await tester.pumpAndSettle();
      expect(navigator.currentState!.canPop(), isFalse);
      expect(find.byType(BecomeRiderScreen), findsNothing);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('Switch to customer dashboard'));
      await tester.tap(find.text('Switch to customer dashboard'));
      await waitFor(tester, find.byType(MainNavigationScreen));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await auth.signOut();
      cart.dispose();
    },
    skip: focus.isNotEmpty && focus != 'roles',
  );
  testWidgets(
    'custom builder saves recipe and mixed checkout creates linked deliveries',
    (tester) async {
      final auth = FirebaseAuth.instance;
      await auth.signInWithEmailAndPassword(
        email: 'customer@demo.bloom.test',
        password: 'DemoPass123!',
      );
      final db = FirebaseFirestore.instance;
      final before =
          (await db
                  .collection('orders')
                  .where('customerId', isEqualTo: 'demo_customer')
                  .get())
              .docs
              .map((d) => d.id)
              .toSet();
      final cart = CartProvider();
      await cart.switchUser('demo_customer');
      cart.clear();
      await cart.flush();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: const MaterialApp(
            key: Key('builder-journey'),
            home: BouquetBuilderScreen(),
          ),
        ),
      );
      await waitFor(tester, find.byTooltip('Add one stem'));
      await tester.ensureVisible(find.byTooltip('Add one stem').first);
      await tester.tap(find.byTooltip('Add one stem').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Recipe'));
      await waitFor(tester, find.text('Recipe saved to Favourites'));
      expect(
        (await db.collection('users/demo_customer/favourite_recipes').get())
            .docs,
        isNotEmpty,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.ensureVisible(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(
        tester.element(find.text('Add to Cart')),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(
        find.text('Add to Cart').hitTestable(),
        findsOneWidget,
        reason:
            'Footer rect ${tester.getRect(find.text("Add to Cart"))}; view ${tester.view.physicalSize}',
      );
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      expect(cart.items.single.fulfillmentType, 'custom');
      expect(cart.items.single.unitPrice, 10);
      final selectedStemId = cart.items.single.customStems!.keys.single;
      cart.addReadyMadeItem(
        bouquetId: 'demo_bouquet',
        name: 'Demo Birthday Bouquet',
        imageUrl: '',
        price: 50,
        quantity: 1,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: const MaterialApp(
            key: Key('mixed-cart-journey'),
            home: CartScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('travel separately'), findsOneWidget);
      await tester.ensureVisible(find.text('Proceed to Checkout'));
      await tester.tap(find.text('Proceed to Checkout'));
      await waitFor(tester, find.text('Place demo order'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('confirm-order')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('confirm-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm order'));
      await waitFor(tester, find.text('Track order'));
      final created =
          (await db
                  .collection('orders')
                  .where('customerId', isEqualTo: 'demo_customer')
                  .get())
              .docs
              .where((d) => !before.contains(d.id))
              .toList();
      expect(created.length, 2);
      expect(created.map((d) => d.data()['checkoutGroupId']).toSet().length, 1);
      expect(
        created
            .map((d) => (d.data()['totalAmount'] as num).toDouble())
            .reduce((a, b) => a + b),
        60,
      );
      final stemId = selectedStemId;
      expect(
        (await db.doc('flowers/$stemId').get()).data()!['reservedQuantity'],
        1,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await auth.signOut();
      cart.dispose();
    },
    skip: focus.isNotEmpty && focus != 'mixed',
  );
}
