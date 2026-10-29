import 'dart:io';
import 'dart:ui' as ui;

import 'package:bloom_and_bunch_kl/features/admin/admin_dashboard_screen.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_order_detail_screen.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_shell.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_theme.dart';
import 'package:bloom_and_bunch_kl/features/admin/admin_widgets.dart';
import 'package:bloom_and_bunch_kl/core/widgets/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Browser extends RouteInformationProvider with ChangeNotifier {
  _Browser(String uri) : _value = RouteInformation(uri: Uri.parse(uri));
  RouteInformation _value;
  @override
  RouteInformation get value => _value;
  final reported = <Uri>[];
  void backOrForward(String uri) {
    _value = RouteInformation(uri: Uri.parse(uri));
    notifyListeners();
  }

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    _value = routeInformation;
    reported.add(routeInformation.uri);
  }
}

class _ListPage extends StatelessWidget {
  const _ListPage(this.location);
  final AdminLocation location;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Page: ${location.destination.name}'),
        TextField(
          key: ValueKey('filter-${location.destination.name}'),
          decoration: const InputDecoration(labelText: 'Filter records'),
        ),
        FilledButton(
          onPressed: () => openAdminPage(
            context,
            const AdminOrderDetailScreen(orderId: 'order 42'),
          ),
          child: const Text('Open order'),
        ),
      ],
    ),
  );
}

Widget _page(AdminLocation location) => location.detail == null
    ? _ListPage(location)
    : Scaffold(
        appBar: AppBar(title: const Text('Order details')),
        body: Text('Order: ${location.uri.queryParameters['id']}'),
      );

void _size(WidgetTester tester, double width, {double height = 1000}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  RouteInformationProvider provider, {
  double scale = 1,
  Widget Function(AdminLocation)? builder,
}) => MaterialApp.router(
  debugShowCheckedModeBanner: false,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  routerDelegate: AppRouterDelegate(
    navigatorKey: GlobalKey<NavigatorState>(),
    home: AdminShell(
      routeInformationProvider: provider,
      pageBuilder: builder ?? _page,
    ),
  ),
);

void main() {
  setUpAll(() async {
    final font = FontLoader('Nunito')
      ..addFont(
        rootBundle.load('assets/fonts/nunito/Nunito-VariableFont_wght.ttf'),
      );
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  test('admin URLs validate destinations, details and encoded order IDs', () {
    expect(
      AdminLocation.parse(Uri.parse('/admin')).destination,
      AdminDestination.dashboard,
    );
    expect(
      AdminLocation.parse(Uri.parse('/admin/missing')).uri.path,
      '/admin/dashboard',
    );
    expect(
      AdminLocation.parse(Uri.parse('/admin/orders/detail')).detail,
      isNull,
    );
    expect(
      AdminLocation.parse(Uri.parse('/admin/orders/detail/extra?id=x')).detail,
      isNull,
    );
    final detail = AdminLocation.parse(
      Uri.parse('/admin/orders/detail?id=order%2042'),
    );
    expect(detail.detailLabel, 'Order details');
    expect(detail.uri.queryParameters['id'], 'order 42');
    expect(
      AdminLocation.parse(Uri.parse('/admin/settings/profile')).detail,
      'profile',
    );
  });

  testWidgets(
    'platform browser history reaches the admin router through the app root',
    (tester) async {
      _size(tester, 1440);
      final provider = PlatformRouteInformationProvider(
        initialRouteInformation: RouteInformation(
          uri: Uri.parse('/admin/dashboard'),
        ),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();
      for (final path in [
        '/admin/staff',
        '/admin/orders/detail?id=platform-order',
        '/admin/orders',
      ]) {
        await tester.binding.handlePushRoute(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(provider.value.uri.toString(), path);
      }
      expect(find.text('Page: orders'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'root navigator still supports imperative sign-in and payment routes',
    (tester) async {
      final root = GlobalKey<NavigatorState>();
      final router = AppRouterDelegate(
        navigatorKey: root,
        home: const Scaffold(body: Text('Role gate')),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerDelegate: router));
      await tester.pumpAndSettle();
      root.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Sign in')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      root.currentState!.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      expect(find.text('Role gate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop sidebar is persistent, collapsible and scopes its theme',
    (tester) async {
      _size(tester, 1440);
      final browser = _Browser('/admin/dashboard');
      await tester.pumpWidget(_app(browser));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const ValueKey('admin-nav-dashboard')), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.text('Page: dashboard')),
        ).colorScheme.primary,
        AdminTheme.primary,
      );
      final expanded = tester.getTopLeft(find.text('Page: dashboard')).dx;
      await tester.tap(find.byTooltip('Collapse sidebar').first);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Page: dashboard')).dx,
        lessThan(expanded),
      );
      await tester.tap(find.byKey(const ValueKey('admin-nav-orders')));
      await tester.pumpAndSettle();
      expect(find.text('Page: orders'), findsOneWidget);
      expect(browser.reported.last.path, '/admin/orders');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'details, section changes and browser history retain list state',
    (tester) async {
      _size(tester, 1440);
      final browser = _Browser('/admin/orders?payment=pending');
      await tester.pumpWidget(_app(browser));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('filter-orders')),
        'Keep this filter',
      );
      await tester.tap(find.text('Open order'));
      await tester.pumpAndSettle();
      expect(browser.reported.last.path, '/admin/orders/detail');
      expect(browser.reported.last.queryParameters['id'], 'order 42');
      expect(find.byKey(const ValueKey('admin-nav-orders')), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Keep this filter'), findsOneWidget);
      expect(browser.reported.last.queryParameters['payment'], 'pending');
      await tester.tap(find.byKey(const ValueKey('admin-nav-staff')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-nav-orders')));
      await tester.pumpAndSettle();
      expect(find.text('Keep this filter'), findsOneWidget);
      browser.backOrForward('/admin/staff');
      await tester.pumpAndSettle();
      expect(find.text('Page: staff'), findsOneWidget);
      browser.backOrForward('/admin/orders?payment=pending');
      await tester.pumpAndSettle();
      expect(find.text('Keep this filter'), findsOneWidget);
      browser.backOrForward('/admin/orders/detail?id=order%2042');
      await tester.pumpAndSettle();
      expect(find.text('Order: order 42'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a direct detail link loads its parent and returns safely', (
    tester,
  ) async {
    _size(tester, 1280);
    final browser = _Browser('/admin/orders/detail?id=direct-link');
    await tester.pumpWidget(_app(browser));
    await tester.pumpAndSettle();
    expect(find.text('Order: direct-link'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Page: orders'), findsOneWidget);
    expect(browser.reported.last.path, '/admin/orders');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 768.0]) {
    testWidgets('drawer navigation fits $width pixels with large text', (
      tester,
    ) async {
      _size(tester, width, height: 800);
      final browser = _Browser('/admin/dashboard');
      await tester.pumpWidget(_app(browser, scale: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-nav-orders')),
      );
      await tester.tap(find.byKey(const ValueKey('admin-nav-orders')));
      await tester.pumpAndSettle();
      expect(find.text('Page: orders'), findsOneWidget);
      expect(find.byTooltip('Open navigation'), findsOneWidget);
      expect(browser.reported.last.path, '/admin/orders');
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [1440.0, 768.0, 390.0]) {
    testWidgets('dashboard visual layout at $width pixels', (tester) async {
      _size(tester, width, height: 1100);
      final browser = _Browser('/admin/dashboard');
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: _app(
            browser,
            builder: (_) => AdminOverview(
              summaryLoader: () async => {
                'generatedAt': DateTime.utc(
                  2026,
                  10,
                  21,
                  2,
                  30,
                ).millisecondsSinceEpoch,
                'todayPaidSen': 68500,
                'monthPaidSen': 1245800,
                'sandboxPaidSen': 15000,
                'monthOrders': 86,
                'preparation': 12,
                'ready': 4,
                'delivering': 7,
                'confirmation': 3,
                'payments': 5,
                'issues': 2,
                'applications': 3,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('ADMIN_CAPTURE')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/admin-preview-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      // Dispose polling timers before the end of this test.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
