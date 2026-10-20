import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================
  // USER
  // =========================

  // Save new user profile to Firestore
  Future<void> saveUserData(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  // Update specific fields on a user's profile (e.g. phone, notification prefs)
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    await _db.collection('users').doc(uid).update(fields);
  }

  /// Changes only the dashboard currently in use. Role entitlements are
  /// server-controlled and rules verify that [activeRole] is owned.
  Future<void> switchActiveRole(String uid, String activeRole) async {
    await _db.collection('users').doc(uid).update({
      'activeRole': activeRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
