import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save new user profile to Firestore
  Future<void> saveUserData(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  // Fetch user profile & role from Firestore (one-time read)
  Future<UserModel?> getUserData(String uid) async {
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Live stream of user profile & role — auto-updates once the doc exists
  Stream<UserModel?> streamUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
}