import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/reorder_service.dart';
import 'order_tracking_screen.dart';

String _friendlyStatus(String raw) {
  switch (raw) {
    case 'Awaiting Preparation':
    case 'Pending':
      return 'Received';
    case 'Processing':
      return 'Assembling';
    case 'Ready for Delivery':
      return 'Ready for rider collection';
    case 'Completed':
      return 'Delivered';
    default:
      return raw;
  }
}

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  Future<void> _orderAgain(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final cart = context.read<CartProvider>();
    try {
      for (final raw in data['items'] as List? ?? []) {
        await ReorderService.add(cart, Map<String, dynamic>.from(raw as Map));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Available items added at current prices.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some items could not be added. Check the current catalogue.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No orders yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final status = _friendlyStatus(data['orderStatus'] ?? 'Pending');
              final total = (data['totalAmount'] ?? 0).toDouble();
              final items = (data['items'] as List<dynamic>? ?? []);
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            createdAt != null
                                ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                                : '',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          Chip(
                            label: Text(
                              status,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: AppColors.primaryRosewood,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderTrackingScreen(orderId: docs[index].id),
                          ),
                        ),
                        child: const Text('Track order'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderTrackingScreen(orderId: docs[index].id),
                          ),
                        ),
                        child: const Text('Track order'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${items.length} item(s)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RM ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryRosewood,
                              fontSize: 16,
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryRosewood,
                            ),
                            icon: const Icon(Icons.replay, size: 16),
                            label: const Text('Order Again'),
                            onPressed: () => _orderAgain(context, data),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
