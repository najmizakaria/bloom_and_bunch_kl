import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../models/order_model.dart';
import 'florist_order_detail_screen.dart';
import '../../../core/widgets/firestore_page.dart';

class FloristOrdersScreen extends StatefulWidget {
  const FloristOrdersScreen({super.key});

  @override
  State<FloristOrdersScreen> createState() => FloristOrdersScreenState();
}

class FloristOrdersScreenState extends State<FloristOrdersScreen> {
  String _selectedStatus = 'Awaiting Preparation';
  void selectStatus(String status) => setState(() => _selectedStatus = status);
  Query<Map<String, dynamic>> _query() => FirebaseFirestore.instance
      .collection('orders')
      .where(
        'orderStatus',
        whereIn: _selectedStatus == 'Awaiting Preparation'
            ? ['Awaiting Preparation', 'Pending']
            : _selectedStatus == 'Delivered'
            ? ['Delivered']
            : [_selectedStatus],
      )
      .orderBy('createdAt', descending: true);

  final Map<String, String> _filters = const {
    'New': 'Awaiting Preparation',
    'Preparing': 'Processing',
    'Ready': 'Ready for Delivery',
    'Awaiting receipt': 'Awaiting Customer Confirmation',
    'Completed': 'Completed',
    'Delivered (older)': 'Delivered',
    'Cancelled': 'Cancelled',
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

  List<OrderModel> _filteredOrders(List<OrderModel> orders) {
    final filtered = orders.where((order) {
      return order.orderStatus == _selectedStatus;
    }).toList();

    if (_selectedStatus == 'Delivered') {
      filtered.sort((first, second) {
        return second.createdAt.compareTo(first.createdAt);
      });
    } else {
      filtered.sort((first, second) {
        return (first.requestedDeliveryDate ?? first.createdAt).compareTo(
          second.requestedDeliveryDate ?? second.createdAt,
        );
      });
    }

    return filtered;
  }

  String _emptyMessage() {
    switch (_selectedStatus) {
      case 'Awaiting Preparation':
        return 'No new orders';
      case 'Processing':
        return 'No orders are being prepared';
      case 'Ready for Delivery':
        return 'No orders are ready for delivery';
      case 'Delivered':
        return 'No completed orders';
      default:
        return 'No orders found';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in _filters.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.key),
                        selected: _selectedStatus == filter.value,
                        onSelected: (_) => selectStatus(filter.value),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FirestorePage(
              key: ValueKey(_selectedStatus),
              query: _query(),
              emptyMessage: _emptyMessage(),
              builder: (context, docs) {
                final orders = _filteredOrders(
                  docs
                      .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
                      .toList(),
                );
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final order in orders)
                      _OrderCard(
                        order: order,
                        orderId: _shortOrderId(order.orderId),
                        orderDate: _formatDate(order.createdAt),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
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
      case 'Awaiting Preparation':
        return AppColors.primaryDark;
      case 'Processing':
        return AppColors.primaryDark;
      case 'Ready for Delivery':
        return AppColors.primaryDark;
      case 'Delivered':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel() {
    if (order.paymentOnHold && order.orderStatus != 'Cancelled') {
      return 'AWAITING PAYMENT';
    }
    switch (order.orderStatus) {
      case 'Awaiting Preparation':
        return 'NEW';
      case 'Processing':
        return 'PREPARING';
      case 'Ready for Delivery':
        return 'READY';
      case 'Completed':
        return 'COMPLETED';
      case 'Delivered':
        return 'DELIVERED (OLDER)';
      default:
        return order.orderStatus.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
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
                      style: const AppTypography.productTitle(),
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
                      style: AppTypography.badge(color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Placed $orderDate',
                style: AppTypography.caption(color: Colors.grey.shade600),
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery time',
                          style: AppTypography.caption(color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.deliveryTimeSlot,
                          style: const AppTypography.label(),
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
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recipient',
                          style: AppTypography.caption(color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.recipientName.isEmpty
                              ? 'Not provided'
                              : order.recipientName,
                          style: const AppTypography.label(),
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
                    color: AppColors.primaryDark.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.primaryDark,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Preparation required',
                        style: AppTypography.label(
                          color: AppColors.primaryDark,
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
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  Text(
                    'RM ${order.totalAmount.toStringAsFixed(2)}',
                    style: const AppTypography.price(color: AppColors.primary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
