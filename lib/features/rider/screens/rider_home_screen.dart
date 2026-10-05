import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/widgets/firestore_page.dart';
import '../../../core/widgets/logout_tile.dart';
import '../../../models/delivery_job_model.dart';
import '../../../models/order_model.dart';
import '../../../models/user_model.dart';
import 'rider_available_job_screen.dart';
import 'rider_order_detail_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});
  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  bool _switching = false;
  int _index = 0;
  String? _queryUid;
  final Map<String, Query<Map<String, dynamic>>> _queries = {};
  Stream<UserModel?>? _userStream;
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
      _index = 0;
      _visited
        ..clear()
        ..add(0);
    }
    final available = _queries.putIfAbsent(
      'available',
      () => db
          .collection('delivery_jobs')
          .where('orderStatus', isEqualTo: 'Ready for Delivery')
          .where('riderId', isNull: true)
          .where('hasValidAddress', isEqualTo: true)
          .where('hasValidCoordinates', isEqualTo: true)
          .orderBy('createdAt', descending: true),
    );
    final assigned = _queries.putIfAbsent(
      'assigned',
      () => db
          .collection('orders')
          .where('riderId', isEqualTo: uid)
          .where(
            'orderStatus',
            whereIn: ['Out for Delivery', 'Awaiting Customer Confirmation'],
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
    Widget orders(Query<Map<String, dynamic>> query, String empty) =>
        FirestorePage(
          query: query,
          emptyMessage: empty,
          builder: (context, docs) => ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final doc in docs)
                Builder(
                  builder: (context) {
                    final order = OrderModel.fromMap(doc.data(), doc.id);
                    return Card(
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
                            builder: (_) =>
                                RiderOrderDetailScreen(order: order),
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
          title: const Text('Delivery workspace'),
        ),
        body: IndexedStack(
          index: _index,
          children:
              [
                    FirestorePage(
                      query: available,
                      emptyMessage:
                          'No eligible deliveries are waiting for pickup.',
                      builder: (context, docs) => ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final doc in docs)
                            Builder(
                              builder: (context) {
                                final job = DeliveryJobModel.fromMap(
                                  doc.data(),
                                  doc.id,
                                );
                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.location_city),
                                    title: Text(job.deliveryArea),
                                    subtitle: Text(
                                      job.deliveryTimeSlot.isEmpty
                                          ? 'Contact the store for timing'
                                          : job.deliveryTimeSlot,
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () async {
                                      final accepted =
                                          await Navigator.push<String>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  RiderAvailableJobScreen(
                                                    job: job,
                                                  ),
                                            ),
                                          );
                                      if (mounted && accepted != null) {
                                        _select(1);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    orders(
                      assigned,
                      'You have no active delivery. Choose one from Available jobs.',
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
                                          setState(() => _switching = true);
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'Available jobs',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
              label: 'Deliveries',
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
