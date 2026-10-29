import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../features/customer/screens/payment_screen.dart';

class PaymentLinkNavigatorObserver extends NavigatorObserver {
  final changes = ValueNotifier<int>(0);

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    changes.value++;
  }
}

class PaymentLinkSession extends StatefulWidget {
  const PaymentLinkSession({
    super.key,
    required this.child,
    required this.links,
    required this.navigatorKey,
    required this.routeChanges,
    this.authIds,
    this.paymentBuilder,
  });
  final Widget child;
  final ValueNotifier<String?> links;
  final GlobalKey<NavigatorState> navigatorKey;
  final Listenable routeChanges;
  final Stream<String?>? authIds;
  final Widget Function(String)? paymentBuilder;

  @override
  State<PaymentLinkSession> createState() => _PaymentLinkSessionState();
}

class _PaymentLinkSessionState extends State<PaymentLinkSession> {
  StreamSubscription<String?>? _auth;
  String? _uid, _activeId;
  bool _scheduled = false;
  bool _waitingForSignIn = false;

  @override
  void initState() {
    super.initState();
    widget.links.addListener(_schedule);
    widget.routeChanges.addListener(_schedule);
    _auth =
        (widget.authIds ??
                FirebaseAuth.instance.authStateChanges().map(
                  (user) => user?.uid,
                ))
            .listen((uid) {
              _uid = uid;
              _schedule();
            });
    _schedule();
  }

  void _schedule() {
    if (widget.links.value == null) return;
    if (_uid == null) {
      _waitingForSignIn = true;
      return;
    }
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _uid == null) return;
      final id = widget.links.value;
      final navigator = widget.navigatorKey.currentState;
      if (id == null || navigator == null) return;
      // Login/Google sign-in pops its route after the auth event arrives.
      // Wait for that navigation so it cannot pop the payment return too.
      if (_waitingForSignIn && navigator.canPop()) return;
      _waitingForSignIn = false;
      widget.links.value = null;
      if (_activeId == id) return;
      _activeId = id;
      navigator.popUntil((route) => route.isFirst);
      navigator
          .push<void>(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/payment-return'),
              builder: (_) =>
                  widget.paymentBuilder?.call(id) ??
                  PaymentScreen.fromReturn(paymentId: id),
            ),
          )
          .whenComplete(() {
            if (mounted && _activeId == id) _activeId = null;
          });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.links.removeListener(_schedule);
    widget.routeChanges.removeListener(_schedule);
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
