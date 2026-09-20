import 'dart:async';
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/core/widgets/auth_cart_sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestUser implements User {
  @override
  final String uid;
  TestUser(this.uid);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('sign-out and account changes close private pushed routes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final changes = StreamController<User?>();
    addTearDown(changes.close);
    final navigator = GlobalKey<NavigatorState>();
    final cart = CartProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: AuthCartSync(
          navigatorKey: navigator,
          authChanges: changes.stream,
          child: MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('Root')),
          ),
        ),
      ),
    );
    changes.add(TestUser('alice'));
    await tester.pumpAndSettle();
    for (final nextUser in [TestUser('bob'), null]) {
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Private order')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private order'), findsOneWidget);
      changes.add(nextUser);
      await tester.pumpAndSettle();
      expect(find.text('Private order'), findsNothing);
      expect(navigator.currentState!.canPop(), false);
    }
  });
}
