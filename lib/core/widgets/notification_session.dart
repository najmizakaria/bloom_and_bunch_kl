import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../../features/customer/screens/order_tracking_screen.dart';
import '../../features/admin/admin_activity_screen.dart';

class NotificationSession extends StatefulWidget {
  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final GlobalKey<NavigatorState> navigatorKey;
  const NotificationSession({
    super.key,
    required this.child,
    required this.messengerKey,
    required this.navigatorKey,
  });
  @override
  State<NotificationSession> createState() => _NotificationSessionState();
}

class _NotificationSessionState extends State<NotificationSession> {
  StreamSubscription<User?>? _auth;
  StreamSubscription<String>? _tokens;
  StreamSubscription<RemoteMessage>? _messages, _opened;
  void _open(RemoteMessage message) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null &&
        message.data['adminUid'] == uid &&
        message.data['adminAlertId'] is String) {
      widget.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const AdminActivityScreen()),
      );
      return;
    }
    if (message.data['customerId'] != FirebaseAuth.instance.currentUser?.uid) {
      return;
    }
    final id = message.data['orderId'];
    if (id is String &&
        id.length >= 8 &&
        FirebaseAuth.instance.currentUser != null) {
      widget.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: id)),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (!NotificationService.supported) return;
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        NotificationService.instance
            .restoreForUser(user.uid)
            .catchError((Object _) {});
      }
    });
    _tokens = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => NotificationService.instance
          .refreshToken(token)
          .catchError((Object _) {}),
    );
    _messages = FirebaseMessaging.onMessage.listen((message) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null ||
          (message.data['customerId'] != uid &&
              message.data['adminUid'] != uid)) {
        return;
      }
      widget.messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            message.notification?.body ?? 'Your order has an update.',
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _open(message),
          ),
        ),
      );
    });
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(_open);
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
          if (message != null && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _open(message);
            });
          }
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _auth?.cancel();
    _tokens?.cancel();
    _messages?.cancel();
    _opened?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
