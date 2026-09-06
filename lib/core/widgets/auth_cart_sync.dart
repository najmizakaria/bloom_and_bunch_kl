import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

/// Sits above AuthGate. Watches Firebase's auth state and clears the shared
/// CartProvider whenever the logged-in uid changes — otherwise the same
/// in-memory cart instance would leak items between different accounts on
/// the same device.
class AuthCartSync extends StatefulWidget {
  final Widget child;
  const AuthCartSync({super.key, required this.child});

  @override
  State<AuthCartSync> createState() => _AuthCartSyncState();
}

class _AuthCartSyncState extends State<AuthCartSync> {
  String? _lastUid;
  StreamSubscription<User?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      final newUid = user?.uid;
      if (newUid != _lastUid) {
        _lastUid = newUid;
        if (mounted) {
          context.read<CartProvider>().clear();
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