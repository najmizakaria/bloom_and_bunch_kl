import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../models/order_model.dart';
import '../screens/florist_order_detail_screen.dart';
import 'florist_inventory_screen.dart';

class FloristHomeScreen extends StatelessWidget {
  const FloristHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('Florist Dashboard 📋'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          // 👇 NEW: Inventory Button
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FloristInventoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch orders ordered by creation time (newest first)
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No orders yet. Time for a coffee! ☕'),
            );
          }

          final orders = snapshot.data!.docs.map((doc) {
            return OrderModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];

              // Color code the status
              Color statusColor = Colors.grey;
              if (order.orderStatus == 'Awaiting Preparation') {
                statusColor = AppColors.primaryDark;
              }
              if (order.orderStatus == 'Processing') {
                statusColor = AppColors.primaryDark;
              }
              if (order.orderStatus == 'Ready for Delivery') {
                statusColor = AppColors.primaryDark;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    'Order: ${order.orderId.substring(0, 8).toUpperCase()}',
                    style: const AppTypography.label(),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('Recipient: ${order.recipientName}'),
                      Text(
                        'RM ${order.totalAmount.toStringAsFixed(2)}',
                        style: const AppTypography.price(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      order.orderStatus == 'Ready for Delivery'
                          ? 'Ready to ship'
                          : order.orderStatus,
                      style: AppTypography.label(color: statusColor),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FloristOrderDetailScreen(order: order),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
