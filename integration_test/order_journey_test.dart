import 'package:bloom_and_bunch_kl/core/config/app_environment.dart';
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/bouquet_detail_screen.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/cart_screen.dart';
import 'package:bloom_and_bunch_kl/core/services/order_service.dart';
import 'package:bloom_and_bunch_kl/models/bouquet_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real callable checkout, rider delivery and owner feedback', (tester) async {
    expect(AppEnvironment.isDemo, isTrue, reason: 'Run only with APP_ENV=demo.');
    await AppEnvironment.initialize();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'customer@demo.bloom.test', password: 'DemoPass123!');
    final db=FirebaseFirestore.instance;
    final product=await db.doc('bouquets/demo_bouquet').get();
    final stock=product.data()!['readyStock'] as int;
    final cart=CartProvider();
    await cart.switchUser('demo_customer'); cart.clear(); await cart.flush();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: cart, child: MaterialApp(home: BouquetDetailScreen(bouquet: BouquetModel.fromMap(product.data()!, product.id)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to cart')); await tester.pumpAndSettle();
    expect(cart.items.single.quantity,1);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: cart, child: const MaterialApp(home: CartScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proceed to Checkout'));
    // Stream/network progress does not always settle; wait for a concrete ready state.
    for(var i=0;i<150&&!find.text('Place demo order').evaluate().isNotEmpty;i++) { await tester.pump(const Duration(milliseconds:200)); }
    expect(find.text('Place demo order'),findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('confirm-order')));
    await tester.tap(find.byKey(const Key('confirm-order')));
    for(var i=0;i<150&&find.text('Track order').evaluate().isEmpty;i++) { await tester.pump(const Duration(milliseconds:200)); }
    expect(find.text('Track order'),findsOneWidget);
    final orders=await db.collection('orders').where('customerId',isEqualTo:'demo_customer').orderBy('createdAt',descending:true).limit(1).get();
    final order=orders.docs.single;
    expect(order.data()['totalAmount'],50);expect(order.data()['orderMode'],'demo');
    expect((await db.doc('bouquets/demo_bouquet').get()).data()!['readyStock'],stock-1);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email:'rider@demo.bloom.test',password:'DemoPass123!');
    await OrderService().transition(order.id,'accept');
    await OrderService().transition(order.id,'deliver');
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email:'customer@demo.bloom.test',password:'DemoPass123!');
    expect((await order.reference.get()).data()!['orderStatus'],'Delivered');
    await FirebaseFunctions.instanceFor(region:'asia-southeast1').httpsCallable('submitOrderFeedback').call({'orderId':order.id,'rating':4,'comment':'Demo transport test'});
    expect((await order.reference.get()).data()!['feedback']['rating'],4);
    await FirebaseAuth.instance.signOut();cart.dispose();
  });
}
