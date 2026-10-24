import 'package:flutter/material.dart';

/// Keeps existing admin actions inside the web workspace's navigator.
class AdminNavigationScope extends InheritedWidget {
  const AdminNavigationScope({
    super.key,
    required this.open,
    required super.child,
  });
  final void Function(Widget page) open;

  static AdminNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminNavigationScope>();

  @override
  bool updateShouldNotify(AdminNavigationScope oldWidget) =>
      open != oldWidget.open;
}

/// Root destinations provide their heading in the workspace, avoiding two bars.
class AdminSectionScope extends InheritedWidget {
  const AdminSectionScope({super.key, required super.child});
  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminSectionScope>() != null;
  @override
  bool updateShouldNotify(AdminSectionScope oldWidget) => false;
}
