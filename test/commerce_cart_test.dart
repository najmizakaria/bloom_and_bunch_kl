import 'dart:async';
import 'dart:convert';
import 'package:bloom_and_bunch_kl/core/providers/cart_provider.dart';
import 'package:bloom_and_bunch_kl/core/services/cart_sync_service.dart';
import 'package:bloom_and_bunch_kl/features/customer/screens/message_card_screen.dart';
import 'package:bloom_and_bunch_kl/models/cart_item_model.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> clone(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class SharedCart extends CartSyncService {
  Map<String, dynamic> data = {
    'checkoutId': 'seed',
    'items': [],
    'messageCards': {},
    'pendingRequest': null,
    'revision': 1,
  };
  final updates = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>?> watch(String uid) async* {
    yield clone(data);
    yield* updates.stream;
  }

  @override
  Future<Map<String, dynamic>?> load(String uid) async => clone(data);
  @override
  Future<int> save(
    Map<String, dynamic> cart,
    int revision,
    String mutationId,
  ) async {
    if (revision != data['revision']) {
      throw FirebaseFunctionsException(
        code: 'aborted',
        message: 'Changed on another device',
      );
    }
    data = {...clone(cart), 'revision': revision + 1, 'mutationId': mutationId};
    updates.add(clone(data));
    return revision + 1;
  }
}

class DelayedFlushCart extends CartProvider {
  final gate = Completer<void>();
  var calls = 0;
  @override
  Future<void> flush() async {
    if (++calls == 1) await gate.future;
    await super.flush();
  }
}

CartItemModel bouquet(String id, {String mode = 'ready_now', String? date}) =>
    CartItemModel(
      id: id,
      type: 'ready',
      bouquetId: id,
      name: id,
      imageUrl: '',
      unitPrice: 50,
      fulfillmentType: mode,
      requestedDeliveryDate: date,
    );
CartItemModel teddy(String date) => CartItemModel(
  id: 'teddy',
  type: 'addon',
  addonId: 'teddy',
  name: 'Teddy',
  imageUrl: '',
  unitPrice: 29,
  requestedDeliveryDate: date,
);
Future<void> events() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'changing accounts while a cart write is pending never copies the checkout to the new account',
    () async {
      final cart = DelayedFlushCart();
      addTearDown(cart.dispose);
      await cart.switchUser('first');
      cart.addSelection([bouquet('roses')]);
      final pending = cart.prepareCheckout({
        'checkoutId': cart.checkoutId,
        'items': cart.items.map((i) => i.toMap()).toList(),
      });
      await cart.switchUser('second');
      cart.gate.complete();
      await expectLater(pending, throwsStateError);
      expect(cart.pendingRequest, isNull);
      expect(cart.isEmpty, isTrue);
    },
  );
  test(
    'bouquet and extras enter atomically and planned bouquets require a date',
    () {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      expect(cart.addSelection([bouquet('roses', mode: 'pre_order')]), false);
      expect(cart.isEmpty, true);
      expect(
        cart.addSelection([
          bouquet('roses', mode: 'pre_order', date: '2026-11-12'),
          teddy('2026-11-12'),
        ]),
        true,
      );
      expect(cart.items.length, 2);
      expect(cart.items.last.type, 'addon');
      expect(cart.totalPrice, 79);
      expect(cart.deliveryGroups, ['2026-11-12']);
      expect(cart.needsDeliveryDates, false);
      final before = cart.items.length;
      expect(
        cart.addSelection(List.generate(20, (i) => bouquet('extra$i'))),
        false,
      );
      expect(cart.items.length, before);
    },
  );
  test(
    'card message and signature survive restore and follow the delivery date',
    () async {
      final cart = CartProvider();
      await cart.switchUser('buyer');
      cart.addSelection([
        bouquet('roses', mode: 'pre_order', date: '2026-11-12'),
        teddy('2026-11-12'),
      ]);
      cart.setMessageCard('2026-11-12', {
        'designId': 'love',
        'designName': 'Lots of Love',
        'message': 'Congratulations!',
        'senderName': 'Najmi',
        'price': 5,
      });
      cart.changeGroupDate('2026-11-12', '2026-11-16');
      expect(cart.totalPrice, 84);
      expect(
        cart.items.every((i) => i.requestedDeliveryDate == '2026-11-16'),
        true,
      );
      final copy = cart.messageCards;
      copy['2026-11-16']!['senderName'] = 'Changed';
      expect(cart.messageCards['2026-11-16']!['senderName'], 'Najmi');
      await cart.flush();
      cart.dispose();
      final restored = CartProvider();
      addTearDown(restored.dispose);
      await restored.switchUser('buyer');
      expect(
        restored.messageCards['2026-11-16']!['message'],
        'Congratulations!',
      );
      expect(restored.items.last.addonId, 'teddy');
      restored.removeItem('roses');
      expect(restored.messageCards, isEmpty);
    },
  );
  test(
    'same account updates another device and conflicting edits require review',
    () async {
      final shared = SharedCart();
      // Both connected providers use the same server state, like phone and web.
      final phone = CartProvider(syncService: shared),
          web = CartProvider(syncService: shared);
      addTearDown(() async {
        phone.dispose();
        web.dispose();
        await shared.updates.close();
      });
      await phone.switchUser('buyer');
      await web.switchUser('buyer');
      await events();
      phone.addSelection([bouquet('roses')]);
      await phone.flush();
      await events();
      expect(web.items.single.bouquetId, 'roses');
      phone.addSelection([bouquet('lily')]);
      web.addSelection([bouquet('tulip')]);
      await phone.flush();
      await expectLater(web.flush(), throwsStateError);
      await events();
      expect(shared.data['items'].length, 2);
      expect(web.errorMessage, isNotNull);
      await web.reloadCloud();
      expect(web.items.map((i) => i.bouquetId), ['roses', 'lily']);
      expect(web.errorMessage, isNull);
    },
  );
  testWidgets(
    'card preview shows selected design, message and editable signature at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageCardPreview(
                designName: 'Lots of Love',
                message: 'Congratulations! 🎉',
                senderName: 'Najmi',
              ),
            ),
          ),
        ),
      );
      expect(find.text('LOTS OF LOVE CARD'), findsOneWidget);
      expect(find.text('Congratulations! 🎉'), findsOneWidget);
      expect(find.text('From,\nNajmi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
