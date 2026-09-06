import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../models/order_model.dart';
import 'florist_order_detail_screen.dart';

class FloristOrdersScreen extends StatefulWidget {
  const FloristOrdersScreen({super.key});

  @override
  State<FloristOrdersScreen> createState() =>
      _FloristOrdersScreenState();
}

class _FloristOrdersScreenState extends State<FloristOrdersScreen> {
  String _selectedStatus = 'Pending';

  final Map<String, String> _filters = const {
    'New': 'Pending',
    'Preparing': 'Processing',
    'Ready': 'Ready for Delivery',
    'Completed': 'Completed',
  };

  String _shortOrderId(String orderId) {
    if (orderId.length <= 8) {
      return orderId.toUpperCase();
    }

    return orderId.substring(0, 8).toUpperCase();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  int _countOrders(List<OrderModel> orders, String status) {
    return orders.where((order) {
      return order.orderStatus == status;
    }).length;
  }

  List<OrderModel> _filteredOrders(List<OrderModel> orders) {
    final filtered = orders.where((order) {
      return order.orderStatus == _selectedStatus;
    }).toList();

    if (_selectedStatus == 'Completed') {
      filtered.sort((first, second) {
        return second.createdAt.compareTo(first.createdAt);
      });
    } else {
      filtered.sort((first, second) {
        return first.createdAt.compareTo(second.createdAt);
      });
    }

    return filtered;
  }

  String _emptyMessage() {
    switch (_selectedStatus) {
      case 'Pending':
        return 'No new orders';
      case 'Processing':
        return 'No orders are being prepared';
      case 'Ready for Delivery':
        return 'No orders are ready for delivery';
      case 'Completed':
        return 'No completed orders';
      default:
        return 'No orders found';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthService().signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load orders.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final orders = snapshot.data?.docs.map((document) {
                return OrderModel.fromMap(
                  document.data() as Map<String, dynamic>,
                  document.id,
                );
              }).toList() ??
              [];

          final visibleOrders = _filteredOrders(orders);

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.entries.map((entry) {
                      final selected = _selectedStatus == entry.value;
                      final count = _countOrders(orders, entry.value);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: selected,
                          label: Text('${entry.key} $count'),
                          selectedColor: Colors.teal,
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: selected
                                ? Colors.teal
                                : Colors.grey.shade300,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedStatus = entry.value;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Expanded(
                child: visibleOrders.isEmpty
                    ? _EmptyOrdersState(
                        message: _emptyMessage(),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleOrders.length,
                        itemBuilder: (context, index) {
                          final order = visibleOrders[index];

                          return _OrderCard(
                            order: order,
                            orderId: _shortOrderId(order.orderId),
                            orderDate: _formatDate(order.createdAt),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.orderId,
    required this.orderDate,
  });

  final OrderModel order;
  final String orderId;
  final String orderDate;

  Color _statusColor() {
    switch (order.orderStatus) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Ready for Delivery':
        return Colors.green;
      case 'Completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel() {
    switch (order.orderStatus) {
      case 'Pending':
        return 'NEW';
      case 'Processing':
        return 'PREPARING';
      case 'Ready for Delivery':
        return 'READY';
      case 'Completed':
        return 'COMPLETED';
      default:
        return order.orderStatus.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) {
                return FloristOrderDetailScreen(order: order);
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ORDER #$orderId',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Placed $orderDate',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 20,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery time',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.deliveryTimeSlot,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 20,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recipient',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.recipientName.isEmpty
                              ? 'Not provided'
                              : order.recipientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (order.requiresPrepTime) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Preparation required',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 26),
              Row(
                children: [
                  Text(
                    '${order.items.length} item(s)',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'RM ${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  const _EmptyOrdersState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Orders will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}