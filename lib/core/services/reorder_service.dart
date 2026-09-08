import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/cart_provider.dart';
import '../../models/bouquet_model.dart';

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
  static Future<void> add(CartProvider cart, Map<String, dynamic> item) async {
    final mode =
        item['fulfillmentType'] ??
        (item['type'] == 'custom' ? 'custom' : 'ready_now');
    if (mode != 'custom') {
      final doc = await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(item['bouquetId'] as String)
          .get();
      if (!doc.exists) throw StateError('Bouquet is no longer offered.');
      final b = BouquetModel.fromMap(doc.data()!, doc.id);
      if (!b.isPublished ||
          (mode == 'ready_now'
              ? (!b.availableForReadyNow || b.readyStock <= 0)
              : !b.availableForPreOrder)) {
        throw StateError('Bouquet is not available in this mode.');
      }
      cart.addReadyMadeItem(
        bouquetId: b.id,
        name: b.name,
        imageUrl: b.imageUrl,
        price: b.price,
        fulfillmentType: mode,
        leadTimeBusinessDays: mode == 'ready_now' ? 0 : b.leadTimeBusinessDays,
      );
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
        final doc = await FirebaseFirestore.instance
            .collection('flowers')
            .doc(e.key)
            .get();
        if (!doc.exists || doc.data()?['availableForCustomOrder'] == false) {
          throw StateError('A flower is no longer offered.');
        }
        names[e.key] = doc.data()!['name'] as String;
        price += (doc.data()!['pricePerStem'] as num).toDouble() * e.value;
      }
      cart.addCustomItem(
        unitPrice: price,
        stems: stems,
        stemNames: names,
        wrapper: wrapper,
        ribbon: ribbon,
        cardNote: item['cardNote'] ?? '',
      );
    }
  }
}
