import 'package:flutter/material.dart';

/// Supplies a safe Home destination for pages embedded in a role workspace.
class PageNavigationScope extends InheritedWidget {
  const PageNavigationScope({
    super.key,
    required this.canGoHome,
    required this.onHome,
    required super.child,
  });
  final bool canGoHome;
  final VoidCallback onHome;
  static PageNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageNavigationScope>();
  @override
  bool updateShouldNotify(PageNavigationScope oldWidget) =>
      canGoHome != oldWidget.canGoHome || onHome != oldWidget.onHome;
}

class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key});
  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final scope = PageNavigationScope.maybeOf(context);
    final canPop = navigator.canPop();
    final canGoHome = scope?.canGoHome ?? false;
    return IconButton(
      tooltip: canPop
          ? 'Back'
          : canGoHome
          ? 'Back to home'
          : 'You are on the home page',
      icon: const BackButtonIcon(),
      onPressed: canPop
          ? () => navigator.maybePop()
          : canGoHome
          ? scope!.onHome
          : null,
    );
  }
}
