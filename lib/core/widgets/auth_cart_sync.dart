import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

/// Switches the cart storage scope with authentication, isolating accounts
/// while preserving each account's own cart and pending checkout retry.
class AuthCartSync extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;
  final Stream<User?>? authChanges;
  const AuthCartSync({
    super.key,
    required this.child,
    this.navigatorKey,
    this.authChanges,
  });

  @override
  State<AuthCartSync> createState() => _AuthCartSyncState();
}

class _AuthCartSyncState extends State<AuthCartSync> {
  String? _lastUid;
  StreamSubscription<User?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = (widget.authChanges ?? FirebaseAuth.instance.authStateChanges())
        .listen((user) {
          final newUid = user?.uid;
          if (newUid != _lastUid) {
            final hadUser = _lastUid != null;
            _lastUid = newUid;
            if (hadUser) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _lastUid == newUid) {
                  widget.navigatorKey?.currentState?.popUntil(
                    (route) => route.isFirst,
                  );
                }
              });
            }
            if (mounted) {
              context.read<CartProvider>().switchUser(newUid);
            }
          }
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
