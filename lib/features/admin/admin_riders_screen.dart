import '../../core/widgets/map_access.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/admin_service.dart';
import 'admin_theme.dart';
import '../../core/utils/malaysia_time.dart';
import 'admin_layout.dart';
import 'admin_widgets.dart';
import 'admin_workspace_screen.dart';
import 'rider_history_screen.dart';
import 'admin_order_detail_screen.dart';
import 'admin_navigation_scope.dart';
import 'rider_contact_editor.dart';

class AdminRidersScreen extends StatelessWidget {
  const AdminRidersScreen({
    super.key,
    this.standalone = false,
    this.initialTab = 0,
  });
  final bool standalone;
  final int initialTab;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    initialIndex: initialTab,
    child: Scaffold(
      backgroundColor: AdminSectionScope.contains(context)
          ? Theme.of(context).scaffoldBackgroundColor
          : AdminTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: standalone,
        title: standalone ? const Text('Riders') : null,
        toolbarHeight: standalone ? kToolbarHeight : 0,
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Directory & locations'),
            Tab(text: 'Applications'),
            Tab(text: 'Delivery history'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          AdminRiderDirectory(),
          AdminWorkspaceScreen(embedded: true),
          RiderHistoryScreen(embedded: true),
        ],
      ),
    ),
  );
}

class AdminRiderDirectory extends StatefulWidget {
  const AdminRiderDirectory({super.key, this.ridersLoader, this.contactSaver});
  final Future<Map<String, dynamic>> Function(String? after)? ridersLoader;
  final Future<void> Function(Map<String, dynamic>)? contactSaver;
  @override
  State<AdminRiderDirectory> createState() => _AdminRiderDirectoryState();
}

class _AdminRiderDirectoryState extends State<AdminRiderDirectory> {
  final List<String?> _pages = [null];
  int _revision = 0;
  bool _showMap = false;
  bool _fresh(Map<String, dynamic> p) {
    final l = p['location'];
    return l is Map &&
        l['updatedAt'] is num &&
        DateTime.now().millisecondsSinceEpoch - (l['updatedAt'] as num) <
            120000 &&
        p['activeDeliveryId'] != null &&
        p['suspended'] != true;
  }

  String _delivery(Map<String, dynamic> p) => p['suspended'] == true
      ? 'Suspended'
      : p['activeDeliveryId'] != null
      ? 'On delivery'
      : 'No active delivery';
  Widget _deliveryBadge(Map<String, dynamic> p) => AdminBadge(
    _delivery(p),
    color: p['suspended'] == true
        ? Color(0xFFB23B35)
        : p['activeDeliveryId'] != null
        ? Color(0xFF237E61)
        : AdminTheme.muted,
  );
  Widget _locationBadge(Map<String, dynamic> p) => AdminBadge(
    p['location'] is! Map
        ? 'Not shared'
        : _fresh(p)
        ? 'Recent location'
        : 'Stale location',
    color: _fresh(p) ? Color(0xFF237E61) : AdminTheme.muted,
  );
  String _updated(Map<String, dynamic> p) {
    final l = p['location'];
    return l is Map && l['updatedAt'] is num
        ? malaysiaTime(
            DateTime.fromMillisecondsSinceEpoch(
              (l['updatedAt'] as num).toInt(),
            ),
          )
        : 'Not recorded';
  }

  Widget _actions(Map<String, dynamic> p) {
    return PopupMenuButton<String>(
      tooltip: 'Actions for ${p['name']}',
      onSelected: (value) async {
        if (value == 'contact') {
          final saved = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => RiderContactEditor(
              rider: p,
              save:
                  widget.contactSaver ??
                  (data) async {
                    await AdminService().call('adminSaveRiderContact', data);
                  },
            ),
          );
          if (saved == true && mounted) {
            setState(() => _revision++);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rider contact approved.')),
              );
            }
          }
        } else if (value == 'order') {
          openAdminPage(
            context,
            AdminOrderDetailScreen(orderId: p['activeDeliveryId']),
          );
        } else {
          final l = p['location'];
          await launchUrl(
            Uri.https('www.google.com', '/maps/search/', {
              'api': '1',
              'query': '${l['latitude']},${l['longitude']}',
            }),
            mode: LaunchMode.externalApplication,
          );
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'contact',
          child: Text('Review delivery contact'),
        ),
        if (p['activeDeliveryId'] != null)
          const PopupMenuItem(
            value: 'order',
            child: Text('View active delivery'),
          ),
        if (_fresh(p))
          const PopupMenuItem(
            value: 'map',
            child: Text('Open location in Google Maps'),
          ),
      ],
    );
  }

  Widget _contact(Map<String, dynamic> p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      AdminBadge(
        p['contactReady'] == true ? 'Contact approved' : 'Contact needs review',
        color: p['contactReady'] == true
            ? const Color(0xFF237E61)
            : const Color(0xFFB23B35),
      ),
      if (p['contactReady'] == true) Text('${p['contactPhone']}'),
    ],
  );

  Widget _map(List<Map<String, dynamic>> located) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      height: 330,
      child: MapAccess(
        child: GoogleMap(
          key: ValueKey(located.map((p) => p['uid']).join(',')),
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (located.first['location']['latitude'] as num).toDouble(),
              (located.first['location']['longitude'] as num).toDouble(),
            ),
            zoom: 12,
          ),
          markers: located
              .map(
                (p) => Marker(
                  markerId: MarkerId(p['uid']),
                  position: LatLng(
                    (p['location']['latitude'] as num).toDouble(),
                    (p['location']['longitude'] as num).toDouble(),
                  ),
                  infoWindow: InfoWindow(title: p['name']),
                ),
              )
              .toSet(),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AdminLoad(
    key: ValueKey(_revision),
    poll: true,
    load: () =>
        widget.ridersLoader?.call(_pages.last) ??
        AdminService().call('adminRiders', {
          if (_pages.last != null) 'after': _pages.last,
        }),
    builder: (data, refresh) {
      final riders = (data['riders'] as List? ?? [])
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
      final located = riders.where(_fresh).toList();
      return AdminPage(
        child: LayoutBuilder(
          builder: (context, box) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              AdminHeading(
                title: 'Rider directory',
                subtitle:
                    'Monitor active deliveries and rider-shared locations.',
                actions: [
                  TextButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  OutlinedButton.icon(
                    onPressed: located.isEmpty
                        ? null
                        : () => setState(() => _showMap = !_showMap),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(_showMap ? 'Hide map' : 'Show map'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                located.isEmpty
                    ? 'No recent shared locations. Riders can share their location during an active delivery.'
                    : '${located.length} recent shared ${located.length == 1 ? 'location' : 'locations'} on this page.',
                style: const TextStyle(color: AdminTheme.muted),
              ),
              const SizedBox(height: 6),
              const Text(
                'Refreshes every 30 seconds · Locations older than two minutes are marked stale.',
                style: TextStyle(color: AdminTheme.muted),
              ),
              const SizedBox(height: 24),
              if (_showMap && located.isNotEmpty) ...[
                _map(located),
                const SizedBox(height: 24),
              ],
              if (riders.isEmpty)
                const AdminEmpty(
                  'No rider accounts found.',
                  icon: Icons.delivery_dining,
                )
              else if (adminUsesTable(context, box.maxWidth))
                AdminTable(
                  columns: const [
                    DataColumn(label: Text('Rider')),
                    DataColumn(label: Text('Delivery status')),
                    DataColumn(label: Text('Delivery contact')),
                    DataColumn(label: Text('Location status')),
                    DataColumn(label: Text('Last update (MYT)')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final p in riders)
                      DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                '${p['name']}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(_deliveryBadge(p)),
                          DataCell(_contact(p)),
                          DataCell(_locationBadge(p)),
                          DataCell(
                            SizedBox(width: 220, child: Text(_updated(p))),
                          ),
                          DataCell(_actions(p)),
                        ],
                      ),
                  ],
                )
              else ...[
                for (final p in riders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${p['name']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                _actions(p),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [_deliveryBadge(p), _locationBadge(p)],
                            ),
                            const SizedBox(height: 12),
                            _contact(p),
                            const SizedBox(height: 12),
                            Text(
                              p['location'] is Map
                                  ? 'Last update: ${_updated(p)}'
                                  : 'This rider has not shared an active-delivery location.',
                              style: const TextStyle(color: AdminTheme.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              AdminPagination(
                page: _pages.length,
                count: riders.length,
                onPrevious: _pages.length > 1
                    ? () => setState(() {
                        _pages.removeLast();
                        _revision++;
                      })
                    : null,
                onNext: data['next'] != null
                    ? () => setState(() {
                        _pages.add(data['next'] as String);
                        _revision++;
                      })
                    : null,
              ),
            ],
          ),
        ),
      );
    },
  );
}
