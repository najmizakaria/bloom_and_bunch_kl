import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/cart_item_model.dart';

class CommerceService {
  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  static Stream<QuerySnapshot<Map<String, dynamic>>> catalogue(String kind) =>
      FirebaseFirestore.instance
          .collection(kind)
          .where('isPublished', isEqualTo: true)
          .limit(100)
          .snapshots();

  static Future<List<String>> dates(CartItemModel item) async {
    final result = await _functions.httpsCallable('deliveryAvailability').call({
      'fulfillmentType': item.type == 'addon'
          ? 'ready_now'
          : item.fulfillmentType,
      'bouquetId': item.bouquetId,
    });
    return List<String>.from(result.data['dates'] as List);
  }

  static Future<void> saveProduct(
    String kind,
    String id,
    int revision,
    Map<String, dynamic> product,
  ) async {
    await _functions.httpsCallable('saveCommerceProduct').call({
      'kind': kind,
      'id': id,
      'revision': revision,
      'product': product,
    });
  }
}
