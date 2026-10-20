import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/user_model.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  static Future<void>? _googleInitialization;

  Future<void> _initializeGoogle() async {
    try {
      await (_googleInitialization ??= GoogleSignIn.instance.initialize());
    } catch (_) {
      _googleInitialization = null;
      rethrow;
    }
  }

  // Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Register New User (email/password)
  Future<UserCredential?> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    String role = 'customer',
  }) async {
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
      try {
        await _firestoreService.saveUserData(newUser);
      } catch (_) {
        // Do not leave a signed-in Auth account without the Firestore profile
        // that AuthGate needs in order to route the user.
        try {
          await result.user!.delete();
        } catch (_) {
          try {
            await _auth.signOut();
          } catch (_) {
            // Preserve the original profile-write failure for the UI.
          }
        }
        rethrow;
      }
    }
    return result;
  }

  // Login User
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    late final UserCredential result;

    if (kIsWeb) {
      // Web uses popup — avoids DWDS hangs / manual client ID setup
      final GoogleAuthProvider authProvider = GoogleAuthProvider();
      result = await _auth.signInWithPopup(authProvider);
    } else {
      await _initializeGoogle();
      // In google_sign_in 7.x, authenticate() throws GoogleSignInException
      // on cancel instead of returning null — must catch it explicitly.
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          return null; // user tapped away from the account picker
        }
        rethrow;
      }

      // .authentication is a synchronous getter in 7.x, not a Future.
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      result = await _auth.signInWithCredential(credential);
    }

    // First-time Google sign-in: create their Firestore profile if missing
    try {
      if (result.user != null) {
        final existing = await _firestoreService.getUserData(result.user!.uid);
        if (existing == null) {
          await _firestoreService.saveUserData(
            UserModel(
              uid: result.user!.uid,
              name: result.user!.displayName ?? 'New User',
              email: result.user!.email ?? '',
              phone: result.user!.phoneNumber ?? '',
              role: 'customer',
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (_) {
      try {
        await _auth.signOut();
      } catch (_) {}
      rethrow;
    }
    return result;
  }

  Future<void> reauthenticateForDeletion({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in.');
    if (user.providerData.any(
      (provider) => provider.providerId == 'password',
    )) {
      if (password == null || password.isEmpty) {
        throw StateError('Enter your current password.');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } else if (user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    )) {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        await _initializeGoogle();
        final account = await GoogleSignIn.instance.authenticate();
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(
            idToken: account.authentication.idToken,
          ),
        );
      }
    } else {
      throw StateError('Sign in again before deleting your account.');
    }
    await user.getIdToken(true);
  }

  Future<void> deleteAccount() async {
    await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('deleteAccount').call();
    await signOut();
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await NotificationService.instance.unregister();
    } catch (_) {}
    try {
      if (!kIsWeb && _googleInitialization != null) {
        await _googleInitialization;
        await GoogleSignIn.instance.signOut();
      }
    } finally {
      await _auth.signOut();
    }
  }
}
