import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/cart_provider.dart';
import '../../models/bouquet_model.dart';
import '../utils/money.dart';

typedef ProductReader =
    Future<Map<String, dynamic>?> Function(String collection, String id);

class ReorderService {
  static const _wrappers = {
    'Kraft Paper (Classic)': 5.0,
    'Pastel Pink Waterproof': 8.0,
    'Minimalist Matte Black': 8.0,
    'Satin White Luxury': 10.0,
  };
  static const _ribbons = {
    'Red Satin': 2.0,
    'Gold Silk': 3.5,
    'Rose Gold Organza': 3.5,
    'Minimalist Twine': 1.5,
  };
  static Future<Map<String, dynamic>?> _read(
    String collection,
    String id,
  ) async =>
      (await FirebaseFirestore.instance.collection(collection).doc(id).get())
          .data();
  static Future<void> add(
    CartProvider cart,
    Map<String, dynamic> item, {
    ProductReader? readDocument,
  }) async {
    final uid = readDocument == null
        ? FirebaseAuth.instance.currentUser?.uid
        : null;
    if (readDocument == null && uid == null) {
      throw StateError('Please sign in.');
    }
    final read = readDocument ?? _read;
    void checkSession() {
      if (readDocument == null && FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('Your sign-in changed. Please retry.');
      }
    }

    final quantity = item['quantity'] as int? ?? 1;
    final mode =
        item['fulfillmentType'] ??
        (item['type'] == 'custom' ? 'custom' : 'ready_now');
    if (mode != 'custom') {
      final id = item['bouquetId'] as String;
      final document = await read('bouquets', id);
      if (document == null) throw StateError('Bouquet is no longer offered.');
      final b = BouquetModel.fromMap(document, id);
      if (!b.isPublished ||
          (mode == 'ready_now'
              ? (!b.availableForReadyNow || b.readyStock <= 0)
              : !b.availableForPreOrder)) {
        throw StateError('Bouquet is not available in this mode.');
      }
      checkSession();
      final added = cart.addReadyMadeItem(
        quantity: quantity,
        bouquetId: b.id,
        name: b.name,
        imageUrl: b.imageUrl,
        price: b.price,
        fulfillmentType: mode,
        leadTimeBusinessDays: mode == 'ready_now' ? 0 : b.leadTimeBusinessDays,
      );
      if (!added) throw StateError(cart.errorMessage!);
    } else {
      final stems = Map<String, int>.from(item['customStems'] as Map);
      final names = <String, String>{};
      final wrapper = item['wrapper'] as String,
          ribbon = item['ribbon'] as String;
      if (!_wrappers.containsKey(wrapper) || !_ribbons.containsKey(ribbon)) {
        throw StateError('Please select wrapping again in the builder.');
      }
      var price = _wrappers[wrapper]! + _ribbons[ribbon]!;
      for (final e in stems.entries) {
        final document = await read('flowers', e.key);
        if (document == null || document['availableForCustomOrder'] == false) {
          throw StateError('A flower is no longer offered.');
        }
        names[e.key] = document['name'] as String;
        price += (document['pricePerStem'] as num).toDouble() * e.value;
      }
      checkSession();
      final added = cart.addCustomItem(
        quantity: quantity,
        unitPrice: Money.round(price),
        stems: stems,
        stemNames: names,
        wrapper: wrapper,
        ribbon: ribbon,
        cardNote: item['cardNote'] ?? '',
      );
      if (!added) throw StateError(cart.errorMessage!);
    }
  }
}
