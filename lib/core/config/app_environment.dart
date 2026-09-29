import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../firebase_options.dart';

class AppEnvironment {
  static const name = String.fromEnvironment('APP_ENV', defaultValue: 'production');
  static const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '127.0.0.1');
  static bool get isDemo => name == 'demo';
  static bool _connected = false;
  static Future<void> initialize() async {
    if (!['demo', 'staging', 'production'].contains(name)) throw StateError('Invalid APP_ENV.');
    const stagingId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    final options = isDemo
        ? const FirebaseOptions(apiKey: 'demo-key', appId: '1:123456789:android:demo', messagingSenderId: '123456789', projectId: 'demo-bloom', storageBucket: 'demo-bloom.appspot.com')
        : name == 'staging'
        ? const FirebaseOptions(apiKey: String.fromEnvironment('FIREBASE_API_KEY'), appId: String.fromEnvironment('FIREBASE_APP_ID'), messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'), projectId: stagingId, storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'), authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'))
        : DefaultFirebaseOptions.currentPlatform;
    if (name == 'staging' && (stagingId.isEmpty || stagingId == 'bloom-and-bunch-kl' || options.apiKey.isEmpty || options.appId.isEmpty)) throw StateError('Provide a separate staging Firebase configuration.');
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    if (Firebase.app().options.projectId != options.projectId) throw StateError('Firebase environment mismatch. Restart the app.');
    if (isDemo && !_connected) {
      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, const int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099), automaticHostMapping: false);
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, const int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 18080), automaticHostMapping: false);
      FirebaseFunctions.instanceFor(region: 'asia-southeast1').useFunctionsEmulator(emulatorHost, const int.fromEnvironment('FUNCTIONS_EMULATOR_PORT', defaultValue: 5001), automaticHostMapping: false);
      await FirebaseStorage.instance.useStorageEmulator(emulatorHost, const int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 19199), automaticHostMapping: false);
      _connected = true;
    }
  }
}
