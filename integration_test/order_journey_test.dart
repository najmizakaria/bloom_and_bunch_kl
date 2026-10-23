import 'package:bloom_and_bunch_kl/core/services/order_service.dart';
import 'package:bloom_and_bunch_kl/core/utils/malaysia_time.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/address_book_screen.dart';
import 'package:bloom_and_bunch_kl/core/services/address_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bloom_and_bunch_kl/core/services/favourites_service.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/become_rider_screen.dart';
import 'package:bloom_and_bunch_kl/features/auth/screens/auth_gate.dart';
import 'package:bloom_and_bunch_kl/features/admin/rider_history_screen.dart';
import 'package:bloom_and_bunch_kl/core/config/app_environment.dart';
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/core/services/cart_sync_service.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/bouquet_detail_screen.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/cart_screen.dart';
import 'package:bloom_and_bunch_kl/models/order_model.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/bouquet_builder_screen.dart';
import 'package:bloom_and_bunch_kl/features/rider/screens/rider_order_detail_screen.dart';
import 'package:bloom_and_bunch_kl/features/rider/screens/rider_available_job_screen.dart';
import 'package:bloom_and_bunch_kl/features/rider/widgets/delivery_job_card.dart';
import 'package:bloom_and_bunch_kl/features/rider/widgets/rider_delivery_details.dart';
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
import 'package:bloom_and_bunch_kl/features/admin/admin_settings_screen.dart';
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
    expect(
      finder,
      findsWidgets,
      reason:
          'Visible text: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(" | ")}',
    );
  }

  Future<void> finishBouquetOptions(
    WidgetTester tester, {
    bool planned = false,
    bool addTeddy = false,
  }) async {
    await waitFor(tester, find.text('Make it extra special'));
    if (addTeddy) {
      await waitFor(tester, find.text('Teddy Bear'));
      await tester.scrollUntilVisible(
        find.text('Teddy Bear'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      final card = find.ancestor(
        of: find.text('Teddy Bear'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: card, matching: find.byTooltip('Add one')),
      );
      await tester.pumpAndSettle();
    }
    if (planned) {
      await tester.scrollUntilVisible(
        find.text('Choose delivery date'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Choose delivery date'));
      await waitFor(tester, find.byType(DatePickerDialog));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.text('Add bouquet and extras to cart'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add bouquet and extras to cart'));
    await tester.pumpAndSettle();
  }

  Finder availableDelivery(String orderId) => find.byWidgetPredicate(
    (widget) => widget is DeliveryJobCard && widget.job.orderId == orderId,
    description: 'available delivery card for $orderId',
  );

  Future<void> openAvailableDelivery(
    WidgetTester tester,
    String orderId,
  ) async {
    await waitFor(tester, find.byType(DeliveryJobCard));
    final view = find.descendant(
      of: availableDelivery(orderId),
      matching: find.text('View delivery'),
    );
    await tester.scrollUntilVisible(
      view,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(view);
    await waitFor(tester, find.byType(RiderAvailableJobScreen));
    await tester.pumpAndSettle();
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
    final addressNavigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        key: const Key('create-address-journey'),
        navigatorKey: addressNavigator,
        home: const Scaffold(body: Text('Address test root')),
      ),
    );
    await tester.pumpAndSettle();
    final addressClosed = addressNavigator.currentState!.push(
      MaterialPageRoute(
        builder: (_) => DeliveryAddressFormScreen(
          detectLocationOnOpen: false,
          selectPin: (_, _) async => const LatLng(3.139, 101.687),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> addressField(String label, String value) async {
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

    await addressField('Label *', 'Browser created address');
    await addressField('Full address *', '12 Test Street, Kuala Lumpur');
    await addressField('Town / City *', 'Kuala Lumpur');
    await addressField('Postcode *', '50000');
    await addressField('State / Federal territory *', 'Kuala Lumpur');
    await addressField('Recipient name *', 'Browser recipient');
    await addressField('Phone *', '0123456789');
    await tester.scrollUntilVisible(
      find.text('Confirm delivery pin *'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm delivery pin *'));
    await tester.pumpAndSettle();
    expect(find.text('Review delivery pin'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save address'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Save address').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Save address'));
    await waitFor(tester, find.text('Address test root'));
    await addressClosed;
    await tester.pumpAndSettle();
    final savedAddress = await AddressService().defaultAddress();
    expect(savedAddress!.label, 'Browser created address');
    expect(savedAddress.address, '12 Test Street, Kuala Lumpur');
    expect(savedAddress.latitude, 3.139);
    expect(
      (await db.doc('users/demo_customer').get()).data()!['defaultAddressId'],
      savedAddress.id,
    );
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
    await tester.tap(find.text('Choose add-ons'));
    await tester.pumpAndSettle();
    expect(cart.isEmpty, isTrue);
    await finishBouquetOptions(tester);
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
    await waitFor(tester, find.text('Place Order'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('confirm-order')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Stream/network progress does not always settle; wait for a concrete ready state.
    for (
      var i = 0;
      i < 150 && !find.text('Place Order').evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Place Order'), findsOneWidget);
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
    await openAvailableDelivery(tester, order.id);
    await tester.tap(find.text('Accept Delivery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept delivery').last);
    await waitFor(tester, find.byType(NavigationBar));
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
    await tester.scrollUntilVisible(
      find.text('Mark as Delivered'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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
    'customer Browse keeps navigation, florist cards choose filters and all roles expose logout',
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
      final adminMenu = find.byTooltip('Open navigation');
      if (adminMenu.evaluate().isNotEmpty) {
        await tester.tap(adminMenu);
        await tester.pumpAndSettle();
      }
      final ridersNav = find.byKey(const ValueKey('admin-nav-riders'));
      await tester.ensureVisible(ridersNav);
      await tester.pumpAndSettle();
      await tester.tap(ridersNav);
      await waitFor(tester, find.text('Delivery history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delivery history'));
      final confirmedHistory = find.byWidgetPredicate(
        (widget) =>
            widget is AdminDeliveryRecords &&
            widget.records.any(
              (record) =>
                  record['orderStatus'] == 'Completed' &&
                  record['customerAcceptedAt'] is Timestamp,
            ),
        description: 'delivery history with a server-recorded customer receipt',
      );
      await waitFor(tester, confirmedHistory);
      final confirmedOrder = tester
          .widget<AdminDeliveryRecords>(confirmedHistory)
          .records
          .firstWhere((record) => record['customerAcceptedAt'] is Timestamp);
      expect(find.text('Receipt confirmed — order completed'), findsWidgets);
      expect(
        find.textContaining(
          malaysiaTime(
            (confirmedOrder['customerAcceptedAt'] as Timestamp).toDate(),
          ),
        ),
        findsWidgets,
      );
      await tester.tap(find.byTooltip('Admin account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings & log out'));
      await waitFor(tester, find.byType(AdminSettingsScreen));
      await tester.scrollUntilVisible(
        find.text('Log out'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(AdminSettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
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
      await waitFor(tester, find.byType(NavigationBar));
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
      final cart = CartProvider(syncService: CartSyncService());
      await cart.switchUser('demo_customer');
      for (var i = 0; i < 100 && !cart.accountCartReady; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(cart.accountCartReady, isTrue);
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
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(
        tester.element(find.text('Continue')),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(
        find.text('Continue').hitTestable(),
        findsOneWidget,
        reason:
            'Footer rect ${tester.getRect(find.text("Continue"))}; view ${tester.view.physicalSize}',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(cart.isEmpty, isTrue);
      await finishBouquetOptions(tester, planned: true, addTeddy: true);
      final custom = cart.items.singleWhere((item) => item.type == 'custom');
      expect(custom.fulfillmentType, 'custom');
      expect(custom.unitPrice, 10);
      expect(
        cart.items.singleWhere((item) => item.type == 'addon').unitPrice,
        29,
      );
      final selectedStemId = custom.customStems!.keys.single;
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
      expect(find.textContaining('one payment and receipt'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Add a message card (optional)').first,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add a message card (optional)').first);
      await waitFor(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lots of Love · RM 5.00').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Browser gift message',
      );
      await tester.scrollUntilVisible(
        find.byType(TextFormField).last,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextFormField).last, 'Browser sender');
      await tester.scrollUntilVisible(
        find.text('Save message card'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save message card'));
      await tester.pumpAndSettle();
      expect(
        cart.messageCards[custom.deliveryGroupKey]!['senderName'],
        'Browser sender',
      );
      await cart.flush();
      final mirror = CartProvider(syncService: CartSyncService());
      await mirror.switchUser('demo_customer');
      for (var i = 0; i < 100 && !mirror.accountCartReady; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(mirror.items.length, 3);
      expect(
        mirror.messageCards[custom.deliveryGroupKey]!['senderName'],
        'Browser sender',
      );
      mirror.dispose();
      await tester.ensureVisible(find.text('Proceed to Checkout'));
      await tester.tap(find.text('Proceed to Checkout'));
      await waitFor(tester, find.text('Place Order'));
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
        94,
      );
      expect(
        created
            .singleWhere((doc) => doc.data()['messageCard'] != null)
            .data()['messageCard']['message'],
        'Browser gift message',
      );
      expect(
        (await db.doc('addons/demo_teddy').get()).data()!['stockQuantity'],
        19,
      );
      await tester.scrollUntilVisible(
        find.text('View combined receipt'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('View combined receipt'));
      await waitFor(tester, find.text('Total: RM 94.00'));
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
  testWidgets(
    'rider queue hides own purchases and blocks another delivery until receipt',
    (tester) async {
      final auth = FirebaseAuth.instance;
      await auth.signInWithEmailAndPassword(
        email: 'rider@demo.bloom.test',
        password: 'DemoPass123!',
      );
      await tester.pumpWidget(
        const MaterialApp(
          key: Key('queue-rider-journey'),
          home: RiderHomeScreen(),
        ),
      );
      await waitFor(tester, find.byType(DeliveryJobCard));
      expect(availableDelivery('fixture_queue_own'), findsNothing);
      expect(availableDelivery('fixture_queue_waiting'), findsNothing);
      expect(find.textContaining('Own purchase area'), findsNothing);
      expect(find.textContaining('Preparation preview area'), findsNothing);
      await openAvailableDelivery(tester, 'fixture_queue_ready');
      await tester.tap(find.text('Accept Delivery'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept delivery').last);
      await waitFor(
        tester,
        find.byWidgetPredicate(
          (widget) => widget is NavigationBar && widget.selectedIndex == 1,
        ),
      );
      // A tab switch alone does not prove the accepted order is reachable.
      final acceptedDetails = find.byWidgetPredicate(
        (widget) =>
            widget is RiderDeliveryDetails &&
            widget.order.orderId == 'fixture_queue_ready',
      );
      await waitFor(tester, acceptedDetails);
      expect(find.textContaining('Out for Delivery'), findsWidgets);
      final openActions = find.text('Open map and delivery actions');
      await tester.scrollUntilVisible(
        openActions,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(openActions);
      await waitFor(tester, find.byType(RiderOrderDetailScreen));
      await waitFor(
        tester,
        find.descendant(
          of: find.byType(RiderOrderDetailScreen),
          matching: find.byType(RiderDeliveryDetails),
        ),
      );
      expect(find.text('Queue recipient'), findsWidgets);
      expect(find.text('Private street, Queue fixture area'), findsWidgets);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Available'));
      await tester.pumpAndSettle();
      final availableScroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      availableScroll.position.jumpTo(availableScroll.position.minScrollExtent);
      await tester.pump();
      await waitFor(tester, find.text('Open My Delivery'));
      await openAvailableDelivery(tester, 'fixture_queue_spare');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Complete current delivery first',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await OrderService().transition('fixture_queue_ready', 'deliver');
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'customer@demo.bloom.test',
        password: 'DemoPass123!',
      );
      await OrderService().transition('fixture_queue_ready', 'confirmReceived');
      await auth.signOut();
    },
    skip: focus.isNotEmpty && focus != 'queue',
  );
}
