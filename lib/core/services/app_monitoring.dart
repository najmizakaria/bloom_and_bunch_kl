import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../config/app_environment.dart';
import '../config/web_configuration.dart';

class AppMonitoring {
  static bool _enabled = false;
  static bool get native => !kIsWeb && [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS].contains(defaultTargetPlatform);
  static Future<void> initialize() async {
    _enabled = !AppEnvironment.isDemo && const bool.fromEnvironment('ENABLE_MONITORING');
    if (kIsWeb || native) await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(_enabled);
    if (native) await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(_enabled);
    if (!AppEnvironment.isDemo && const bool.fromEnvironment('ENABLE_APP_CHECK')) {
      final webKey = WebConfiguration.appCheckSiteKey;
      if (kIsWeb && webKey.isEmpty) throw StateError('App Check web site key is required.');
      await FirebaseAppCheck.instance.activate(providerWeb: kIsWeb ? ReCaptchaV3Provider(webKey) : null);
    }
    if (!_enabled) return;
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(report(details.exception, details.stack ?? StackTrace.current));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(report(error, stack));
      return true;
    };
  }
  // Only allow fixed event names. Never send address, phone, card message or raw error text.
  static Future<void> event(String name) async {
    if (!_enabled || !(kIsWeb || native)) return;
    if (!{'product_viewed', 'cart_added', 'checkout_started', 'checkout_confirmed', 'checkout_failed', 'feedback_submitted'}.contains(name)) return;
    try { await FirebaseAnalytics.instance.logEvent(name: name); } catch (_) { /* Monitoring must not interrupt shopping. */ }
  }
  static Future<void> report(Object error, StackTrace stack) async {
    if (!_enabled) return;
    try {
      if (native) {
        await FirebaseCrashlytics.instance.recordError(error.runtimeType.toString(), stack, reason: 'Unhandled app error');
      } else if (kIsWeb) {
        await FirebaseAnalytics.instance.logEvent(name: 'app_error', parameters: {'error_type': error.runtimeType.toString()});
      }
    } catch (_) { /* Preserve the original error handling path. */ }
  }
}
