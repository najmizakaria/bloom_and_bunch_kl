import '../config/app_environment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  final _messaging = FirebaseMessaging.instance;
  String? _token;
  static bool get supported =>
      !AppEnvironment.isDemo && (kIsWeb ||
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform));
  Future<String> _getToken() async {
    const vapid = String.fromEnvironment('FCM_VAPID_KEY_WEB');
    final token = await _messaging.getToken(
      vapidKey: kIsWeb && vapid.isNotEmpty ? vapid : null,
    );
    if (token == null) {
      throw StateError('This device could not register for notifications.');
    }
    _token = token;
    return token;
  }

  Future<void> setEnabled(bool enabled) async {
    if (!supported) {
      throw StateError('Push notifications are not supported on this device.');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in.');
    String? token = _token;
    if (enabled) {
      final settings = await _messaging.requestPermission();
      if (![
        AuthorizationStatus.authorized,
        AuthorizationStatus.provisional,
      ].contains(settings.authorizationStatus)) {
        throw StateError(
          'Notifications are blocked. Allow them in your device or browser settings.',
        );
      }
      token = await _getToken();
    }
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Your sign-in changed. Please retry.');
    }
    await _functions.httpsCallable('updateNotificationSettings').call({
      'enabled': enabled,
      'token': token,
    });
  }

  Future<void> restoreForUser(String uid) async {
    if (!supported) return;
    final profile = await FirebaseFirestore.instance.doc('users/$uid').get();
    if (profile.data()?['notificationsEnabled'] != true) return;
    final settings = await _messaging.getNotificationSettings();
    if (![
      AuthorizationStatus.authorized,
      AuthorizationStatus.provisional,
    ].contains(settings.authorizationStatus)) {
      return;
    }
    final token = await _getToken();
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;
    await _functions.httpsCallable('updateNotificationSettings').call({
      'enabled': true,
      'token': token,
    });
    if (!kIsWeb) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> refreshToken(String token) async {
    _token = token;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile = await FirebaseFirestore.instance.doc('users/$uid').get();
    if (profile.data()?['notificationsEnabled'] != true ||
        FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    await _functions.httpsCallable('updateNotificationSettings').call({
      'enabled': true,
      'token': token,
    });
  }

  Future<void> unregister() async {
    if (!supported) return;
    try {
      if (_token != null) {
        await _functions.httpsCallable('unregisterNotificationDevice').call({
          'token': _token,
        });
      }
    } finally {
      _token = null;
      await _messaging.deleteToken();
    }
  }
}
