import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/page_navigation.dart';
import '../florist/screens/florist_inventory_screen.dart';
import '../florist/screens/florist_products_screen.dart';
import '../support/store_operations_screen.dart';
import 'admin_activity_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_inventory_alerts.dart';
import 'admin_navigation_scope.dart';
import 'admin_order_detail_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_riders_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_theme.dart';

enum AdminDestination {
  dashboard('Dashboard', Icons.speed_outlined, 'Overview'),
  orders('Orders', Icons.receipt_long_outlined, 'Store operations'),
  inventory('Inventory', Icons.inventory_2_outlined, 'Store operations'),
  stock('Stock alerts', Icons.warning_amber_outlined, 'Store operations'),
  support(
    'Support & feedback',
    Icons.support_agent_outlined,
    'Store operations',
  ),
  riders('Riders', Icons.delivery_dining_outlined, 'People'),
  staff('Staff', Icons.people_outline, 'People'),
  alerts('Alerts', Icons.notifications_outlined, 'Administration'),
  activity('Activity history', Icons.history, 'Administration'),
  settings('Settings', Icons.settings_outlined, 'Administration');

  const AdminDestination(this.label, this.icon, this.group);
  final String label, group;
  final IconData icon;
  Uri get uri => Uri(path: '/admin/$name');
}

/// A small, explicit URL surface; backend authorization remains in AuthGate.
class AdminLocation {
  AdminLocation._(this.uri, this.destination, this.detail);
  factory AdminLocation.parse(Uri uri) {
    final parts = uri.pathSegments;
    if (parts.length < 2 || parts.first != 'admin') {
      return AdminLocation._(
        AdminDestination.dashboard.uri,
        AdminDestination.dashboard,
        null,
      );
    }
    final destination = AdminDestination.values
        .where((d) => d.name == parts[1])
        .firstOrNull;
    if (destination == null) {
      return AdminLocation.parse(AdminDestination.dashboard.uri);
    }
    final detail = parts.length == 3 ? parts[2] : null;
    final allowedDetail = switch (destination) {
      AdminDestination.orders =>
        detail == 'detail' && (uri.queryParameters['id']?.isNotEmpty ?? false),
      AdminDestination.settings => [
        'profile',
        'preferences',
        'store',
      ].contains(detail),
      AdminDestination.staff => detail == 'create',
      _ => false,
    };
    if (parts.length > 2 && !allowedDetail) {
      return AdminLocation.parse(destination.uri);
    }
    return AdminLocation._(uri, destination, detail);
  }
  final Uri uri;
  final AdminDestination destination;
  final String? detail;
  Uri get rootUri => detail == null ? uri : destination.uri;
  String? get detailLabel => switch (detail) {
    'detail' => 'Order details',
    'profile' => 'Admin profile',
    'preferences' => 'Notification preferences',
    'store' => 'Store operations',
    'create' => 'Create staff account',
    _ => null,
  };
}

class AdminRouteParser extends RouteInformationParser<AdminLocation> {
  const AdminRouteParser();
  @override
  Future<AdminLocation> parseRouteInformation(
    RouteInformation routeInformation,
  ) => SynchronousFuture(AdminLocation.parse(routeInformation.uri));
  @override
  RouteInformation restoreRouteInformation(AdminLocation configuration) =>
      RouteInformation(uri: configuration.uri);
}

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    this.accountName = 'Administrator',
    this.initialUri,
    this.routeInformationProvider,
    this.pageBuilder,
  });
  final String accountName;
  final Uri? initialUri;
  final RouteInformationProvider? routeInformationProvider;

  /// Allows isolated navigation/layout verification without live services.
  final Widget Function(AdminLocation location)? pageBuilder;
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final _delegate = _AdminRouterDelegate(
    accountName: widget.accountName,
    pageBuilder: widget.pageBuilder,
  );
  late final _provider =
      widget.routeInformationProvider ??
      PlatformRouteInformationProvider(
        initialRouteInformation: RouteInformation(
          uri:
              widget.initialUri ??
              Uri.parse(
                WidgetsBinding.instance.platformDispatcher.defaultRouteName,
              ),
        ),
      );
  final _back = RootBackButtonDispatcher();
  late final _theme = AdminTheme.light;
  @override
  void dispose() {
    _delegate.dispose();
    if (widget.routeInformationProvider == null) {
      (_provider as PlatformRouteInformationProvider).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _theme,
    child: Router<AdminLocation>(
      routeInformationProvider: _provider,
      routeInformationParser: const AdminRouteParser(),
      routerDelegate: _delegate,
      backButtonDispatcher: _back,
    ),
  );
}

class _AdminRouterDelegate extends RouterDelegate<AdminLocation>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AdminLocation> {
  _AdminRouterDelegate({required this.accountName, this.pageBuilder});
  final String accountName;
  final Widget Function(AdminLocation)? pageBuilder;
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final Map<AdminDestination, ({Uri uri, Widget page})> _visited = {};
  AdminLocation _location = AdminLocation.parse(AdminDestination.dashboard.uri);
  bool _collapsed = false;
  @override
  AdminLocation get currentConfiguration => _location;

  Widget _buildPage(AdminLocation location) {
    if (pageBuilder != null) return pageBuilder!(location);
    final q = location.uri.queryParameters;
    if (location.detail != null) {
      return switch (location.detail) {
        'detail' => AdminOrderDetailScreen(orderId: q['id']!),
        'profile' => const AdminProfileScreen(),
        'preferences' => const AdminPreferencesScreen(),
        'store' => const AdminStorePolicyScreen(),
        'create' => AdminCreateStaffScreen(
          onCreated: () {
            _visited.remove(AdminDestination.staff);
            _apply(_location);
            notifyListeners();
          },
        ),
        _ => const SizedBox.shrink(),
      };
    }
    return switch (location.destination) {
      AdminDestination.dashboard => const AdminOverview(),
      AdminDestination.orders => AdminOrdersScreen(
        initialStatus: q['status'],
        initialPayment: q['payment'],
        initialMode: q['mode'],
        initialDateField: q['dateField'] == 'paidAt' ? 'paidAt' : 'createdAt',
        initialDates: _dates(q),
      ),
      AdminDestination.inventory => FloristProductsScreen(
        initialTab: switch (q['tab']) {
          'flowers' => 1,
          'addons' => 2,
          'cards' => 3,
          _ => 0,
        },
      ),
      AdminDestination.stock => const AdminInventoryAlerts(),
      AdminDestination.support => const StoreOperationsScreen(),
      AdminDestination.riders => AdminRidersScreen(
        initialTab: int.tryParse(q['tab'] ?? '')?.clamp(0, 2) ?? 0,
      ),
      AdminDestination.staff => const AdminStaffScreen(),
      AdminDestination.alerts => const AdminActivityScreen(),
      AdminDestination.activity => const AdminActivityScreen(audit: true),
      AdminDestination.settings => const AdminSettingsScreen(),
    };
  }

  static DateTimeRange? _dates(Map<String, String> q) {
    final start = DateTime.tryParse(q['from'] ?? ''),
        end = DateTime.tryParse(q['to'] ?? '');
    return start != null && end != null && !start.isAfter(end)
        ? DateTimeRange(start: start, end: end)
        : null;
  }

  void _apply(AdminLocation location) {
    _location = location;
    final previous = _visited[location.destination];
    // Detail URLs do not discard the list's current filters or scroll position.
    if (previous == null ||
        (location.detail == null && previous.uri != location.uri)) {
      final root = AdminLocation.parse(location.rootUri);
      _visited[location.destination] = (uri: root.uri, page: _buildPage(root));
    }
  }

  @override
  Future<void> setNewRoutePath(AdminLocation configuration) async {
    _apply(configuration);
  }

  void _go(Uri uri) {
    _apply(AdminLocation.parse(uri));
    notifyListeners();
  }

  void _open(Widget page) {
    Uri? uri;
    if (page is AdminOrdersScreen) {
      uri = Uri(
        path: '/admin/orders',
        queryParameters: {
          if (page.initialStatus != null) 'status': page.initialStatus!,
          if (page.initialPayment != null) 'payment': page.initialPayment!,
          if (page.initialMode != null) 'mode': page.initialMode!,
          'dateField': page.initialDateField,
          if (page.initialDates != null) ...{
            'from': page.initialDates!.start.toIso8601String(),
            'to': page.initialDates!.end.toIso8601String(),
          },
        },
      );
    } else if (page is AdminOrderDetailScreen) {
      uri = Uri(
        path: '/admin/orders/detail',
        queryParameters: {'id': page.orderId},
      );
    } else if (page is AdminRidersScreen) {
      uri = Uri(
        path: '/admin/riders',
        queryParameters: {'tab': '${page.initialTab}'},
      );
    } else if (page is FloristProductsScreen) {
      uri = AdminDestination.inventory.uri;
    } else if (page is FloristInventoryScreen) {
      uri = Uri(path: '/admin/inventory', queryParameters: {'tab': 'flowers'});
    } else if (page is AdminInventoryAlerts) {
      uri = AdminDestination.stock.uri;
    } else if (page is StoreOperationsScreen) {
      uri = AdminDestination.support.uri;
    } else if (page is AdminActivityScreen) {
      uri = (page.audit ? AdminDestination.activity : AdminDestination.alerts)
          .uri;
    } else if (page is AdminProfileScreen) {
      uri = Uri(path: '/admin/settings/profile');
    } else if (page is AdminPreferencesScreen) {
      uri = Uri(path: '/admin/settings/preferences');
    } else if (page is AdminStorePolicyScreen) {
      uri = Uri(path: '/admin/settings/store');
    } else if (page is AdminCreateStaffScreen) {
      uri = Uri(path: '/admin/staff/create');
    }
    if (uri != null) {
      _go(uri);
    } else {
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => page),
      );
    }
  }

  void _removed(Page<Object?> page) {
    if (page.key == ValueKey(_location.uri.toString()) &&
        _location.detail != null) {
      final root = _visited[_location.destination]!.uri;
      _go(root);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_visited.isEmpty) _apply(_location);
    final destination = _location.destination;
    return AdminNavigationScope(
      open: _open,
      child: PageNavigationScope(
        canGoHome:
            destination != AdminDestination.dashboard ||
            _location.detail != null,
        onHome: () => _go(AdminDestination.dashboard.uri),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop =
                constraints.maxWidth >= 1000 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.5;
            return Scaffold(
              drawer: desktop
                  ? null
                  : Drawer(
                      width: 260,
                      child: _sidebar(context, collapsed: false, drawer: true),
                    ),
              body: Row(
                children: [
                  if (desktop)
                    SizedBox(
                      width: _collapsed ? 104 : 224,
                      child: _sidebar(context, collapsed: _collapsed),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        _toolbar(context, desktop),
                        _breadcrumbs(context),
                        Expanded(
                          child: Navigator(
                            key: navigatorKey,
                            onDidRemovePage: _removed,
                            pages: [
                              MaterialPage<void>(
                                key: const ValueKey('admin-sections'),
                                child: AdminSectionScope(
                                  child: IndexedStack(
                                    index: destination.index,
                                    children: [
                                      for (final d in AdminDestination.values)
                                        TickerMode(
                                          enabled: d == destination,
                                          child: KeyedSubtree(
                                            key: ValueKey(
                                              _visited[d]?.uri.toString() ??
                                                  d.name,
                                            ),
                                            child:
                                                _visited[d]?.page ??
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_location.detail != null)
                                MaterialPage<void>(
                                  key: ValueKey(_location.uri.toString()),
                                  child: _buildPage(_location),
                                ),
                            ],
                          ),
                        ),
                        if (constraints.maxHeight >= 700 &&
                            MediaQuery.textScalerOf(context).scale(1) <= 1.3)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Bloom & Bunch KL · Administration',
                              style: TextStyle(
                                fontSize: 11,
                                color: AdminTheme.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context, bool desktop) => Container(
    height: 70,
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: AdminTheme.ink.withValues(alpha: .08),
          blurRadius: 18,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            tooltip: desktop
                ? (_collapsed ? 'Expand sidebar' : 'Collapse sidebar')
                : 'Open navigation',
            onPressed: desktop
                ? () {
                    _collapsed = !_collapsed;
                    notifyListeners();
                  }
                : () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu, color: AdminTheme.primary),
          ),
        ),
        if (desktop) ...[
          const SizedBox(width: 12),
          const Icon(
            Icons.local_florist_outlined,
            size: 19,
            color: AdminTheme.muted,
          ),
          const SizedBox(width: 8),
          const Text(
            'Store administration',
            style: TextStyle(color: AdminTheme.muted),
          ),
        ],
        const Spacer(),
        IconButton(
          tooltip: 'Admin alerts',
          onPressed: () => _go(AdminDestination.alerts.uri),
          icon: const Icon(Icons.notifications_outlined),
        ),
        const SizedBox(height: 30, child: VerticalDivider(width: 24)),
        Flexible(
          child: PopupMenuButton<String>(
            tooltip: 'Admin account',
            onSelected: (value) => _go(
              Uri(
                path: value.isEmpty
                    ? '/admin/settings'
                    : '/admin/settings/$value',
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('My profile')),
              PopupMenuItem(
                value: 'preferences',
                child: Text('Notification preferences'),
              ),
              PopupMenuItem(value: '', child: Text('Settings & log out')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (desktop) ...[
                    Flexible(
                      child: Text(
                        accountName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: AdminTheme.background,
                    child: Icon(
                      Icons.person_outline,
                      size: 22,
                      color: AdminTheme.muted,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _breadcrumbs(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: () => _go(AdminDestination.dashboard.uri),
            child: const Text('Admin'),
          ),
          const Icon(Icons.chevron_right, size: 16, color: AdminTheme.muted),
          TextButton(
            onPressed: _location.detail == null
                ? null
                : () => _go(_visited[_location.destination]!.uri),
            child: Text(_location.destination.label),
          ),
          if (_location.detailLabel != null) ...[
            const Icon(Icons.chevron_right, size: 16, color: AdminTheme.muted),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _location.detailLabel!,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _sidebar(
    BuildContext context, {
    required bool collapsed,
    bool drawer = false,
  }) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AdminTheme.primary, AdminTheme.primaryDark],
      ),
    ),
    child: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_florist,
                    color: Colors.white,
                    size: 30,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'BLOOM & BUNCH\nADMIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                for (var i = 0; i < AdminDestination.values.length; i++) ...[
                  if (i == 0 ||
                      AdminDestination.values[i].group !=
                          AdminDestination.values[i - 1].group) ...[
                    const Divider(
                      color: Colors.white24,
                      indent: 16,
                      endIndent: 16,
                      height: 20,
                    ),
                    if (!collapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                        child: Text(
                          AdminDestination.values[i].group.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                  ],
                  _navItem(
                    context,
                    AdminDestination.values[i],
                    collapsed,
                    drawer,
                  ),
                ],
                if (!drawer) ...[
                  const Divider(
                    color: Colors.white24,
                    indent: 16,
                    endIndent: 16,
                    height: 28,
                  ),
                  Center(
                    child: IconButton.filledTonal(
                      tooltip: collapsed
                          ? 'Expand sidebar'
                          : 'Collapse sidebar',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .15),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        _collapsed = !_collapsed;
                        notifyListeners();
                      },
                      icon: Icon(
                        collapsed ? Icons.chevron_right : Icons.chevron_left,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _navItem(
    BuildContext context,
    AdminDestination d,
    bool collapsed,
    bool drawer,
  ) {
    final selected = d == _location.destination;
    final color = selected ? Colors.white : Colors.white.withValues(alpha: .78);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: Tooltip(
          message: collapsed ? d.label : '',
          child: Material(
            color: selected
                ? Colors.white.withValues(alpha: .13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            child: InkWell(
              key: ValueKey('admin-nav-${d.name}'),
              borderRadius: BorderRadius.circular(5),
              hoverColor: Colors.white.withValues(alpha: .1),
              focusColor: Colors.white.withValues(alpha: .2),
              onTap: () {
                if (drawer) Navigator.of(context).pop();
                _go(_visited[d]?.uri ?? d.uri);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 4 : 12,
                  vertical: 13,
                ),
                child: collapsed
                    ? Column(
                        children: [
                          Icon(d.icon, size: 21, color: color),
                          const SizedBox(height: 5),
                          Text(
                            d.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: color, fontSize: 10),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(d.icon, size: 19, color: color),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              d.label,
                              style: TextStyle(
                                color: color,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
