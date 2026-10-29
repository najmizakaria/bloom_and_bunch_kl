import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';

void main() {
  testWidgets(
    'root Back stays visible and disabled with no previous destination',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: const PageBackButton(),
              centerTitle: false,
              title: const Text('Home'),
            ),
          ),
        ),
      );
      expect(find.byType(BackButtonIcon), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      expect(
        tester.getCenter(find.byType(BackButtonIcon)).dx,
        lessThan(tester.getCenter(find.text('Home')).dx),
      );
    },
  );
  testWidgets('tab Back returns to Home without popping the role workspace', (
    tester,
  ) async {
    var atHome = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) => PageNavigationScope(
            canGoHome: !atHome,
            onHome: () => update(() => atHome = true),
            child: Scaffold(
              appBar: AppBar(
                leading: const PageBackButton(),
                title: Text(atHome ? 'Home' : 'More'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Back to home'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });
  testWidgets(
    'detail Back pops the route before returning a workspace tab Home',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Workspace')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => PageNavigationScope(
            canGoHome: true,
            onHome: () => fail('Must pop the detail route first'),
            child: Scaffold(
              appBar: AppBar(
                leading: const PageBackButton(),
                centerTitle: false,
                title: const Text('Details'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Workspace'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
    },
  );
}
