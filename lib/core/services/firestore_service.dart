import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/order_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================
  // USER
  // =========================

  // Save new user profile to Firestore
  Future<void> saveUserData(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  // Fetch user profile & role from Firestore
  Future<UserModel?> getUserData(String uid) async {
    DocumentSnapshot doc =
        await _db.collection('users').doc(uid).get();

    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(
        doc.data() as Map<String, dynamic>,
      );
    }

    return null;
  }

  // =========================
  // ORDERS
  // =========================

  // Get all orders from Firebase in real-time
  Stream<List<OrderModel>> getAllOrders() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return OrderModel.fromMap(
          doc.data(),
          doc.id,
        );
      }).toList();
    });
  }
}