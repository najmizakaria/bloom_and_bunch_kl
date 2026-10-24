import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CartSyncService {
  Future<Map<String, dynamic>?> load(String uid) async =>
      (await FirebaseFirestore.instance
              .doc('users/$uid/cart/current')
              .get(const GetOptions(source: Source.server)))
          .data();
  Stream<Map<String, dynamic>?> watch(String uid) => FirebaseFirestore.instance
      .doc('users/$uid/cart/current')
      .snapshots(includeMetadataChanges: true)
      .where((doc) => !doc.metadata.isFromCache)
      .map((doc) => doc.exists ? doc.data() : null);

  Future<int> save(
    Map<String, dynamic> cart,
    int revision,
    String mutationId,
  ) async {
    final result =
        await FirebaseFunctions.instanceFor(
          region: 'asia-southeast1',
        ).httpsCallable('saveCart').call({
          'cart': cart,
          'revision': revision,
          'mutationId': mutationId,
        });
    return (result.data['revision'] as num).toInt();
  }
}
