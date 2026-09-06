import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiderApplicationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> get _appDoc =>
      _db.collection('rider_applications').doc(_uid);

  /// Emits null if never applied, otherwise the application doc data
  /// (includes a 'status' field: 'pending' | 'approved' | 'rejected').
  Stream<Map<String, dynamic>?> applicationStatusStream() {
    if (_uid == null) return const Stream.empty();
    return _appDoc.snapshots().map((doc) => doc.exists ? doc.data() : null);
  }

  Future<void> submitApplication({
    required String name,
    required String phone,
    required String vehicleType,
    required String reason,
  }) async {
    if (_uid == null) return;
    await _appDoc.set({
      'uid': _uid,
      'name': name,
      'phone': phone,
      'vehicleType': vehicleType,
      'reason': reason,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }
}