import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/saved_address_model.dart';

class AddressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _addresses =>
      _db.collection('users').doc(_uid).collection('addresses');

  Stream<List<SavedAddressModel>> addressesStream() {
    if (_uid == null) return const Stream.empty();
    return _addresses.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => SavedAddressModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  Future<void> saveAddress(SavedAddressModel address) async {
    if (_uid == null) return;
    if (address.id.isEmpty) {
      await _addresses.add(address.toMap());
    } else {
      await _addresses.doc(address.id).set(address.toMap());
    }
  }

  Future<void> deleteAddress(String id) async {
    if (_uid == null) return;
    await _addresses.doc(id).delete();
  }
}