import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/saved_address_model.dart';

class AddressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw StateError('Please sign in.'));
  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(_uid);
  CollectionReference<Map<String, dynamic>> get _addresses =>
      _user.collection('addresses');
  Stream<List<SavedAddressModel>> addressesStream() =>
      _addresses.snapshots().map(
        (s) => s.docs
            .map((d) => SavedAddressModel.fromMap(d.data(), d.id))
            .toList(),
      );
  Future<SavedAddressModel?> defaultAddress() async {
    final user = await _user.get();
    final id = user.data()?['defaultAddressId'] as String?;
    if (id != null) {
      final doc = await _addresses.doc(id).get();
      if (doc.exists) return SavedAddressModel.fromMap(doc.data()!, doc.id);
    }
    final all = await _addresses.limit(100).get();
    if (all.docs.isEmpty) return null;
    final doc = all.docs.firstWhere(
      (d) => d.data()['isDefault'] == true,
      orElse: () => all.docs.first,
    );
    return SavedAddressModel.fromMap(doc.data(), doc.id);
  }

  Future<void> saveAddress(SavedAddressModel address) async {
    await _functions.httpsCallable('saveAddress').call({
      'addressId': address.id.isEmpty ? null : address.id,
      'address': address.toMap(),
    });
  }

  Future<void> setDefault(String id) async {
    await _functions.httpsCallable('setDefaultAddress').call({'addressId': id});
  }

  Future<void> deleteAddress(String id) async {
    await _functions.httpsCallable('deleteAddress').call({'addressId': id});
  }
}
