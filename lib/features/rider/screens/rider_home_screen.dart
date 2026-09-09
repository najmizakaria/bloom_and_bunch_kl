import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/delivery_job_model.dart';
import '../../../models/order_model.dart';
import '../../../models/user_model.dart';
import 'rider_available_job_screen.dart';
import 'rider_order_detail_screen.dart';

class RiderHomeScreen extends StatelessWidget {
  const RiderHomeScreen({super.key});

  Future<void> _switchToCustomer(BuildContext context, String uid) async {
    try {
      await FirestoreService().switchActiveRole(uid, 'customer');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to switch dashboards.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rider Dashboard 🛵'),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          actions: [
            StreamBuilder<UserModel?>(
              stream: FirestoreService().streamUserData(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.data?.hasRole('customer') != true) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  tooltip: 'Switch to customer dashboard',
                  icon: const Icon(Icons.storefront_outlined),
                  onPressed: () => _switchToCustomer(context, currentUserId),
                );
              },
            ),
            IconButton(
              tooltip: 'Sign out',
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
              Tab(text: 'My Delivery', icon: Icon(Icons.motorcycle)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAvailableJobs(),
            _buildAssignedOrders(currentUserId),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableJobs() {
    final query = FirebaseFirestore.instance
        .collection('delivery_jobs')
        .where('orderStatus', isEqualTo: 'Ready for Delivery')
        .where('riderId', isNull: true)
        .where('hasValidAddress', isEqualTo: true)
        .where('hasValidCoordinates', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _RiderMessage(
            message: 'Unable to load available deliveries. Please retry.',
          );
        }

        final jobs = (snapshot.data?.docs ?? const [])
            .map((doc) => DeliveryJobModel.fromMap(doc.data(), doc.id))
            .toList();
        if (jobs.isEmpty) {
          return const _RiderMessage(
            message: 'No eligible deliveries are waiting for pickup.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.location_city, color: Colors.deepOrange),
                ),
                title: Text(
                  job.deliveryArea,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    job.deliveryTimeSlot.isEmpty
                        ? 'As soon as possible'
                        : job.deliveryTimeSlot,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RiderAvailableJobScreen(job: job),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAssignedOrders(String currentUserId) {
    final query = FirebaseFirestore.instance
        .collection('orders')
        .where('riderId', isEqualTo: currentUserId)
        .where('orderStatus', isEqualTo: 'Out for Delivery')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _RiderMessage(
            message: 'Unable to load your active delivery. Please retry.',
          );
        }

        final orders = (snapshot.data?.docs ?? const [])
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .toList();
        if (orders.isEmpty) {
          return const _RiderMessage(
            message: 'You have no active delivery. Choose one from Available.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.location_on, color: Colors.deepOrange),
                ),
                title: Text(
                  order.deliveryAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Recipient: ${order.recipientName}'),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RiderOrderDetailScreen(order: order),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RiderMessage extends StatelessWidget {
  final String message;

  const _RiderMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
