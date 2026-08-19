import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../models/order_model.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),

      // =========================
      // APP BAR
      // =========================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              'Bloom & Bunch KL',
              style: TextStyle(
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
      body: StreamBuilder<List<OrderModel>>(
        stream: firestoreService.getAllOrders(),
        builder: (context, snapshot) {

          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Error
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading orders:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          // Get orders
          final orders = snapshot.data ?? [];

          // =========================
          // CALCULATE SALES
          // =========================

          final today = DateTime.now();

          double todaySales = 0;

          for (final order in orders) {
            if (order.createdAt.year == today.year &&
                order.createdAt.month == today.month &&
                order.createdAt.day == today.day) {
              todaySales += order.totalAmount;
            }
          }

          // =========================
          // ACTIVE ORDERS
          // =========================

          final activeOrders = orders.where((order) {
            return order.orderStatus != 'Delivered' &&
                order.orderStatus != 'Cancelled';
          }).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        value: '$activeOrders Orders',
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
                    child: _buildOrderCard(order),
                  ),
                ),
              ],
            ),
          );
        },
      ),

      // =========================
      // BOTTOM NAVIGATION
      // =========================

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.pink,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // =========================
  // METRIC CARD
  // =========================

  static Widget _buildMetricCard({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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

  // =========================
  // ORDER CARD
  // =========================

  static Widget _buildOrderCard(
    OrderModel order,
  ) {
    final statusColor =
        _getStatusColor(order.orderStatus);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                        style:
                            const TextStyle(
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
        ],
      ),
    );
  }

  // =========================
  // STATUS COLOR
  // =========================

  static Color _getStatusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;

      case 'accepted':
        return Colors.deepOrange;

      case 'preparing':
        return Colors.amber;

      case 'out for delivery':
        return Colors.blue;

      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // =========================
  // BOUQUET DESCRIPTION
  // =========================

  static String _getBouquetDescription(
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