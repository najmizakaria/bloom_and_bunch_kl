import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Public browser configuration. Build defines win; local debug runs can use
/// the existing .env asset without additional flutter run arguments.
class WebConfiguration {
  static String get firebaseApiKey => _resolve(
    'FIREBASE_API_KEY_WEB',
    const String.fromEnvironment('FIREBASE_API_KEY_WEB'),
  );
  static String get mapsApiKey => _resolve(
    'MAPS_API_KEY_WEB',
    const String.fromEnvironment('MAPS_API_KEY_WEB'),
  );
  static String get vapidKey => _resolve(
    'FCM_VAPID_KEY_WEB',
    const String.fromEnvironment('FCM_VAPID_KEY_WEB'),
  );
  static String get appCheckSiteKey => _resolve(
    'APP_CHECK_WEB_SITE_KEY',
    const String.fromEnvironment('APP_CHECK_WEB_SITE_KEY'),
  );

  static String _resolve(String name, String compiled) {
    if (compiled.trim().isNotEmpty) return compiled.trim();
    // Release web builds continue to use their explicit build configuration.
    if (kIsWeb && !kDebugMode) return '';
    return dotenv.isInitialized ? (dotenv.env[name]?.trim() ?? '') : '';
  }
}
