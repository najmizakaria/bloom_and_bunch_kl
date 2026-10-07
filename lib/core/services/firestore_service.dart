import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';

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
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();

    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
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
            return OrderModel.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _db.collection('orders').doc(orderId).update({
      'orderStatus': newStatus,
    });
  }

  // =========================
  // PRODUCTS / STOCK
  // =========================

  // Get all products in real-time
  Stream<List<ProductModel>> getAllProducts() {
    return _db
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ProductModel.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  // Add new product
  Future<void> addProduct(ProductModel product) async {
    await _db.collection('products').add(product.toMap());
  }

  // Update product
  Future<void> updateProduct(ProductModel product) async {
    await _db
        .collection('products')
        .doc(product.productId)
        .update(product.toMap());
  }

  // Delete product
  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }

  // =========================
  // RIDER LOCATION
  // =========================

  // Update rider's current location
  // AND save the location into history
  Future<void> updateRiderLocation({
    required String riderId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final riderRef = _db.collection('users').doc(riderId);

    final locationData = {
      'latitude': latitude,
      'longitude': longitude,
      'address': address ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Update current location
    await riderRef.update({'currentLocation': locationData});

    // Save location history
    await riderRef.collection('locationHistory').add({
      'latitude': latitude,
      'longitude': longitude,
      'address': address ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // GET RIDER CURRENT LOCATION
  // =========================

  Stream<DocumentSnapshot<Map<String, dynamic>>> getRiderLocation(
    String riderId,
  ) {
    return _db.collection('users').doc(riderId).snapshots();
  }

  // =========================
  // GET ALL RIDERS
  // =========================

  // Get rider profiles as UserModel
  Stream<List<UserModel>> getAllRiders() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'rider')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return UserModel.fromMap(doc.data());
          }).toList();
        });
  }

  // =========================
  // GET ALL RIDER DOCUMENTS
  // =========================

  // Used by Admin Rider Map
  // because this contains currentLocation
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllRiderDocuments() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'rider')
        .snapshots();
  }

  // =========================
  // GET RIDER LOCATION HISTORY
  // =========================

  Stream<QuerySnapshot<Map<String, dynamic>>> getRiderLocationHistory(
    String riderId,
  ) {
    return _db
        .collection('users')
        .doc(riderId)
        .collection('locationHistory')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
