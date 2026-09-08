import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import '../../../models/order_model.dart';
import 'rider_order_detail_screen.dart';

class RiderHomeScreen extends StatelessWidget {
  const RiderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rider Dashboard 🛵'),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => AuthService().signOut(),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Available', icon: Icon(Icons.list_alt)),
              Tab(text: 'My Deliveries', icon: Icon(Icons.motorcycle)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Available Deliveries ('Ready for Delivery')
            _buildOrderList(
              query: FirebaseFirestore.instance
                  .collection('orders')
                  .where('orderStatus', isEqualTo: 'Ready for Delivery')
                  .orderBy('createdAt', descending: true),
              emptyMessage: 'No orders waiting for pickup right now!',
            ),

            // TAB 2: My Active Deliveries ('Out for Delivery' assigned to me)
            _buildOrderList(
              query: FirebaseFirestore.instance
                  .collection('orders')
                  .where('riderId', isEqualTo: currentUserId)
                  .where('orderStatus', isEqualTo: 'Out for Delivery')
                  .orderBy('createdAt', descending: true),
              emptyMessage:
                  'You have no active deliveries. Grab one from the available tab!',
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build the list from a Firestore query
  Widget _buildOrderList({required Query query, required String emptyMessage}) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load deliveries. Please retry.'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        final orders = snapshot.data!.docs.map((doc) {
          return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.deepOrange,
                  ),
                ),
                title: Text(
                  order.deliveryAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Recipient: ${order.recipientName}'),
                    Text(
                      'Time: ${order.deliveryTimeSlot}',
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiderOrderDetailScreen(order: order),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
