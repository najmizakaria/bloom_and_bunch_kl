import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../models/order_model.dart';
import 'stock_screen.dart';
import 'staff_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),

      // =========================
      // APP BAR
      // =========================

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getAppBarSubtitle(),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              _getAppBarTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.pink,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.black54,
            ),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),

      // =========================
      // BODY
      // =========================

      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildMonitorTab(),
          const StockScreen(),
          _buildMapTab(),
          const StaffScreen(),
          _buildSettingsTab(),
        ],
      ),

      // =========================
      // BOTTOM NAVIGATION
      // =========================

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,

        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            activeIcon: Icon(Icons.location_on),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Staff',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // =========================================================
  // APP BAR TITLE
  // =========================================================

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Bloom & Bunch KL';
      case 1:
        return 'Stock Management';
      case 2:
        return 'Rider Tracking';
      case 3:
        return 'Staff Management';
      case 4:
        return 'Settings';
      default:
        return 'Bloom & Bunch KL';
    }
  }

  String _getAppBarSubtitle() {
    switch (_currentIndex) {
      case 0:
        return 'Welcome back';
      case 1:
        return 'Manage your products';
      case 2:
        return 'Track rider location';
      case 3:
        return 'Manage your staff';
      case 4:
        return 'Admin preferences';
      default:
        return 'Welcome back';
    }
  }

  // =========================================================
  // MONITOR TAB
  // =========================================================

  Widget _buildMonitorTab() {
    return StreamBuilder<List<OrderModel>>(
      stream: _firestoreService.getAllOrders(),
      builder: (context, snapshot) {
        // LOADING

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // ERROR

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Error loading orders:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final orders = snapshot.data ?? [];

        // =====================================================
        // CALCULATE SALES
        // =====================================================

        final today = DateTime.now();

        double todaySales = 0;

        for (final order in orders) {
          if (order.createdAt.year == today.year &&
              order.createdAt.month == today.month &&
              order.createdAt.day == today.day) {
            todaySales += order.totalAmount;
          }
        }

        // =====================================================
        // ACTIVE ORDERS
        // =====================================================

        final activeOrders = orders.where((order) {
          return order.orderStatus != 'Completed' &&
              order.orderStatus != 'Cancelled';
        }).length;

        // =====================================================
        // CONTENT
        // =====================================================

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // =========================
              // METRICS
              // =========================

              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: "Today's Sales",
                      value:
                          'RM ${todaySales.toStringAsFixed(2)}',
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _buildMetricCard(
                      title: 'Active Queues',
                      value:
                          '$activeOrders Orders',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // =========================
              // LIVE FEED TITLE
              // =========================

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Live Monitoring Feed',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    'Real-time',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink[400],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // =========================
              // ORDERS
              // =========================

              if (orders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'No orders available.',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),

              ...orders.map(
                (order) => Padding(
                  padding:
                      const EdgeInsets.only(bottom: 10),
                  child: _buildOrderCard(
                    context,
                    order,
                    _firestoreService,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // MAP TAB
  // =========================================================

  Widget _buildMapTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
              ),
            ),
            child: const Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 60,
                  color: Colors.pink,
                ),

                SizedBox(height: 12),

                Text(
                  'Rider Live Tracking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Live rider location map will be available here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SETTINGS TAB
  // =========================================================

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSettingsItem(
            icon: Icons.person_outline,
            title: 'Admin Profile',
            subtitle: 'Manage admin account',
            onTap: () {},
          ),

          const SizedBox(height: 10),

          _buildSettingsItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage notifications',
            onTap: () {},
          ),

          const SizedBox(height: 10),

          _buildSettingsItem(
            icon: Icons.security_outlined,
            title: 'Security',
            subtitle: 'Account security settings',
            onTap: () {},
          ),

          const SizedBox(height: 10),

          _buildSettingsItem(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out from admin account',
            onTap: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SETTINGS ITEM
  // =========================================================

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.pink.shade50,
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.pink,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  // =========================================================
  // METRIC CARD
  // =========================================================

  Widget _buildMetricCard({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ORDER CARD
  // =========================================================

  Widget _buildOrderCard(
    BuildContext context,
    OrderModel order,
    FirestoreService firestoreService,
  ) {
    final statusColor =
        _getStatusColor(order.orderStatus);

    const statusOptions = [
      'Pending',
      'Processing',
      'Ready for Delivery',
      'Completed',
    ];

    final currentStatus =
        statusOptions.contains(order.orderStatus)
            ? order.orderStatus
            : 'Pending';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ORDER ID + STATUS

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${order.orderId}',
                style: const TextStyle(
                  color: Colors.pink,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      statusColor.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  order.orderStatus.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // RECIPIENT

          Text(
            order.recipientName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 4),

          // BOUQUET

          Row(
            children: [
              const Icon(
                Icons.local_florist,
                size: 15,
                color: Colors.pink,
              ),

              const SizedBox(width: 5),

              Expanded(
                child: Text(
                  _getBouquetDescription(
                    order.bouquetDetails,
                  ),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          const Divider(),

          const SizedBox(height: 5),

          // LOCATION + PRICE

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 15,
                      color: Colors.red,
                    ),

                    const SizedBox(width: 3),

                    Expanded(
                      child: Text(
                        order.deliveryAddress,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Text(
                'RM ${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // UPDATE STATUS

          const Text(
            'Update Order Status',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 5),

          DropdownButtonFormField<String>(
            value: currentStatus,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              filled: true,
              fillColor:
                  const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(10),
                borderSide:
                    const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(10),
                borderSide:
                    const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
            items: statusOptions.map(
              (status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w500,
                      color:
                          _getStatusColor(status),
                    ),
                  ),
                );
              },
            ).toList(),
            onChanged: (newStatus) async {
              if (newStatus == null ||
                  newStatus ==
                      order.orderStatus) {
                return;
              }

              try {
                await firestoreService
                    .updateOrderStatus(
                  order.orderId,
                  newStatus,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Order #${order.orderId} updated to $newStatus',
                      ),
                      duration:
                          const Duration(
                        seconds: 2,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to update order status: $e',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;

      case 'processing':
        return Colors.deepOrange;

      case 'ready for delivery':
        return Colors.blue;

      case 'completed':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // =========================================================
  // BOUQUET DESCRIPTION
  // =========================================================

  String _getBouquetDescription(
    Map<String, dynamic> details,
  ) {
    if (details.isEmpty) {
      return 'Custom Bouquet';
    }

    final stems = details['stems'];

    if (stems != null) {
      return 'Custom Bouquet • $stems';
    }

    return 'Custom Bouquet';
  }
}