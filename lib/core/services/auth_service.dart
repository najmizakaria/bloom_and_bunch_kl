import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Register New User
  Future<UserCredential?> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    String role = 'customer',
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        UserModel newUser = UserModel(
          uid: result.user!.uid,
          name: name,
          email: email,
          phone: phone,
          role: role,
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveUserData(newUser);
      }
      return result;
    } catch (e) {
      rethrow;
    }
  }

  // =========================
  // CREATE STAFF ACCOUNT
  // =========================

  Future<UserCredential?> createStaffAccount({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    FirebaseApp? secondaryApp;

    try {
      // Create a separate Firebase app instance
      // so the admin account stays logged in.
      secondaryApp = await Firebase.initializeApp(
        name: 'staffRegistration',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Create Firebase Authentication account
      final result = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (result.user != null) {
        final newStaff = UserModel(
          uid: result.user!.uid,
          name: name.trim(),
          email: email.trim(),
          phone: phone.trim(),
          role: role,
          createdAt: DateTime.now(),
        );

        // Save staff profile to Firestore
        await _firestoreService.saveUserData(newStaff);
      }

      return result;
    } finally {
      // Delete secondary app after registration
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  // Login User
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
