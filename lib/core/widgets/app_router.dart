import 'package:flutter/material.dart';

/// Hosts the existing imperative role/auth flows without consuming browser URLs.
/// The authenticated admin workspace owns its route information provider;
/// AuthGate remains mounted beneath every pushed login or payment screen.
class AppRouterDelegate extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  AppRouterDelegate({
    required this.navigatorKey,
    required this.home,
    this.observers = const [],
  });
  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget home;
  final List<NavigatorObserver> observers;

  @override
  Future<void> setNewRoutePath(Object configuration) async {}

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    observers: observers,
    onDidRemovePage: (_) {},
    pages: [MaterialPage<void>(key: const ValueKey('auth-root'), child: home)],
  );
}
