import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/widgets/firestore_page.dart';
import '../../../core/widgets/logout_tile.dart';
import '../../../models/order_model.dart';
import '../../../models/user_model.dart';
import '../../../core/services/delivery_service.dart';
import '../widgets/available_deliveries_list.dart';
import '../widgets/rider_location_sharing.dart';
import 'rider_order_detail_screen.dart';
import '../widgets/rider_delivery_details.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  bool _switching = false;
  int _index = 0;
  String? _queryUid;
  final Map<String, Query<Map<String, dynamic>>> _queries = {};
  Stream<UserModel?>? _userStream;
  Stream<void>? _queueChanges;
  final Set<int> _visited = {0};
  void _select(int index) => setState(() {
    _index = index;
    _visited.add(index);
  });
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }
    final db = FirebaseFirestore.instance;
    if (_queryUid != uid) {
      _queryUid = uid;
      _queries.clear();
      _userStream = FirestoreService().streamUserData(uid);
      _queueChanges = DeliveryService.queueChanges();
      _index = widget.initialIndex;
      _visited
        ..clear()
        ..add(0)
        ..add(_index);
    }
    final assigned = _queries.putIfAbsent(
      'assigned',
      () => db
          .collection('orders')
          .where('riderId', isEqualTo: uid)
          .where(
            'orderStatus',
            whereIn: [
              'Rider assigned',
              'Out for Delivery',
              'Awaiting Customer Confirmation',
            ],
          )
          .orderBy('createdAt', descending: true),
    );
    final history = _queries.putIfAbsent(
      'history',
      () => db
          .collection('orders')
          .where('riderId', isEqualTo: uid)
          .where('orderStatus', whereIn: ['Completed', 'Delivered'])
          .orderBy('createdAt', descending: true),
    );
    Widget orders(
      Query<Map<String, dynamic>> query,
      String empty, {
      bool active = false,
    }) => FirestorePage(
      query: query,
      emptyMessage: empty,
      builder: (context, docs) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final doc in docs)
            Builder(
              builder: (context) {
                final order = OrderModel.fromMap(doc.data(), doc.id);
                if (active) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RiderDeliveryDetails(order: order),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                RiderOrderDetailScreen(order: order),
                          ),
                        ),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Open map and delivery actions'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      order.deliveryAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${order.recipientName}\n${order.orderStatus}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => RiderOrderDetailScreen(order: order),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
    return PageNavigationScope(
      canGoHome: _index != 0,
      onHome: () => _select(0),
      child: Scaffold(
        appBar: AppBar(
          leading: const PageBackButton(),
          centerTitle: false,
          title: Text(
            [
              'Available Deliveries',
              'My Delivery',
              'Delivery History',
              'More',
            ][_index],
          ),
        ),
        body: Column(
          children: [
            const RiderLocationSharing(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children:
                    [
                          AvailableDeliveriesList(
                            key: ValueKey(uid),
                            active: _index == 0,
                            changes: _queueChanges,
                            onMyDelivery: () => _select(1),
                          ),
                          orders(
                            assigned,
                            'You have no active delivery. Choose one from Available Deliveries.',
                            active: true,
                          ),
                          orders(history, 'No completed deliveries yet.'),
                          ListView(
                            children: [
                              StreamBuilder<UserModel?>(
                                stream: _userStream,
                                builder: (context, snapshot) =>
                                    snapshot.data?.hasRole('customer') != true
                                    ? const SizedBox.shrink()
                                    : ListTile(
                                        leading: const Icon(
                                          Icons.storefront_outlined,
                                        ),
                                        title: const Text(
                                          'Switch to customer dashboard',
                                        ),
                                        subtitle: _switching
                                            ? const Text('Switching…')
                                            : null,
                                        onTap: _switching
                                            ? null
                                            : () async {
                                                if (_switching) return;
                                                setState(
                                                  () => _switching = true,
                                                );
                                                final navigator = Navigator.of(
                                                  context,
                                                );
                                                try {
                                                  await FirestoreService()
                                                      .switchActiveRole(
                                                        uid,
                                                        'customer',
                                                      );
                                                  if (mounted) {
                                                    navigator.popUntil(
                                                      (route) => route.isFirst,
                                                    );
                                                  }
                                                } catch (_) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Unable to switch dashboards. Please retry.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted) {
                                                    setState(
                                                      () => _switching = false,
                                                    );
                                                  }
                                                }
                                              },
                                      ),
                              ),
                              const LogoutTile(),
                            ],
                          ),
                        ]
                        .asMap()
                        .entries
                        .map(
                          (entry) => _visited.contains(entry.key)
                              ? entry.value
                              : const SizedBox.shrink(),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'Available',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
              label: 'My Delivery',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
