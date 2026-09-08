import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/saved_address_model.dart';

class AddressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
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
    final ref = address.id.isEmpty
        ? _addresses.doc()
        : _addresses.doc(address.id);
    final user = await _user.get();
    final makeDefault =
        address.isDefault || user.data()?['defaultAddressId'] == null;
    final batch = _db.batch();

    if (makeDefault) {
      final existing = await _addresses.limit(100).get();
      for (final document in existing.docs) {
        if (document.id != ref.id) {
          batch.update(document.reference, {'isDefault': false});
        }
      }
      batch.update(_user, {'defaultAddressId': ref.id});
    }

    batch.set(ref, {...address.toMap(), 'isDefault': makeDefault});
    await batch.commit();
  }

  Future<void> setDefault(String id) async {
    final addresses = await _addresses.limit(100).get();
    if (!addresses.docs.any((document) => document.id == id)) {
      throw StateError('Address no longer exists.');
    }

    final batch = _db.batch();
    for (final document in addresses.docs) {
      batch.update(document.reference, {'isDefault': document.id == id});
    }
    batch.update(_user, {'defaultAddressId': id});
    await batch.commit();
  }

  Future<void> deleteAddress(String id) async {
    final user = await _user.get();
    final batch = _db.batch();
    batch.delete(_addresses.doc(id));

    if (user.data()?['defaultAddressId'] == id) {
      final addresses = await _addresses.limit(100).get();
      final replacements = addresses.docs
          .where((document) => document.id != id)
          .toList();
      if (replacements.isEmpty) {
        batch.update(_user, {'defaultAddressId': FieldValue.delete()});
      } else {
        final replacement = replacements.first;
        batch.update(replacement.reference, {'isDefault': true});
        batch.update(_user, {'defaultAddressId': replacement.id});
      }
    }

    await batch.commit();
  }
}
