import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/constants/fulfillment_constants.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/order_model.dart';
import '../../customer/widgets/order_thumbnail.dart';
import 'florist_order_detail_screen.dart';
import '../../../core/widgets/firestore_page.dart';

class FloristOrdersScreen extends StatefulWidget {
  const FloristOrdersScreen({super.key, this.watchOrders});
  final Stream<List<OrderModel>> Function(String status)? watchOrders;

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
        whereIn: switch (_selectedStatus) {
          'Awaiting Preparation' => ['Awaiting Preparation', 'Pending'],
          'Completed' => ['Completed', 'Delivered'],
          _ => [_selectedStatus],
        },
      )
      .orderBy('createdAt', descending: true);

  final Map<String, String> _filters = const {
    'New': 'Awaiting Preparation',
    'Preparing': 'Processing',
    'Ready to ship': 'Ready for Delivery',
    'Assigned': 'Rider assigned',
    'Delivering': 'Out for Delivery',
    'Awaiting receipt': 'Awaiting Customer Confirmation',
    'Completed': 'Completed',
    'Cancelled': 'Cancelled',
  };

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  List<OrderModel> _filteredOrders(List<OrderModel> orders) {
    final filtered = orders.where((order) {
      return order.orderStatus == _selectedStatus ||
          (_selectedStatus == 'Completed' && order.orderStatus == 'Delivered');
    }).toList();

    filtered.sort((first, second) {
      return (first.requestedDeliveryDate ?? first.createdAt).compareTo(
        second.requestedDeliveryDate ?? second.createdAt,
      );
    });

    return filtered;
  }

  String _emptyMessage() {
    switch (_selectedStatus) {
      case 'Awaiting Preparation':
        return 'No new orders';
      case 'Processing':
        return 'No orders are being prepared';
      case 'Ready for Delivery':
        return 'No orders are ready to ship';
      case 'Rider assigned':
        return 'No orders are waiting for rider collection';
      case 'Out for Delivery':
        return 'No orders are out for delivery';
      case 'Completed':
        return 'No completed orders';
      default:
        return 'No orders found';
    }
  }

  Widget _orders(List<OrderModel> orders) {
    final filtered = _filteredOrders(orders);
    if (filtered.isEmpty) return Center(child: Text(_emptyMessage()));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        for (final order in filtered)
          _OrderCard(order: order, orderDate: _formatDate(order.createdAt)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: true,
        title: const Text('Orders'),
        titleTextStyle:
            Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
              color: AppColors.onPrimary,
            ) ??
            const AppTypography.screenTitle(color: AppColors.onPrimary),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        scrolledUnderElevation: 0,
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
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.cardWhite,
                        checkmarkColor: AppColors.onPrimary,
                        showCheckmark: true,
                        shape: const StadiumBorder(),
                        side: const BorderSide(color: AppColors.primary),
                        labelStyle: AppTypography.label(
                          color: _selectedStatus == filter.value
                              ? AppColors.onPrimary
                              : AppColors.primaryDark,
                        ),
                        onSelected: (_) => selectStatus(filter.value),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: widget.watchOrders != null
                ? StreamBuilder<List<OrderModel>>(
                    key: ValueKey(_selectedStatus),
                    stream: widget.watchOrders!(_selectedStatus),
                    builder: (_, snapshot) => snapshot.hasError
                        ? const Center(
                            child: Text(
                              'Could not load orders. Please try again.',
                            ),
                          )
                        : !snapshot.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : _orders(snapshot.data!),
                  )
                : Theme(
                    data: Theme.of(context).copyWith(
                      floatingActionButtonTheme: FloatingActionButtonThemeData(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    child: FirestorePage(
                      key: ValueKey(_selectedStatus),
                      query: _query(),
                      emptyMessage: _emptyMessage(),
                      builder: (_, docs) => _orders([
                        for (final doc in docs)
                          OrderModel.fromMap(doc.data(), doc.id),
                      ]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.orderDate});

  final OrderModel order;
  final String orderDate;

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
        return 'READY TO SHIP';
      case 'Out for Delivery':
        return 'DELIVERING';
      case 'Awaiting Customer Confirmation':
        return 'AWAITING RECEIPT';
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
    final preview =
        order.items.where((item) => item['type'] != 'addon').firstOrNull ??
        order.items.firstOrNull;
    final progress = switch (order.orderStatus) {
      OrderStatuses.cancelled => null,
      _ when order.paymentOnHold => (0, 'Awaiting payment'),
      OrderStatuses.awaitingPreparation => (1, 'Awaiting preparation'),
      OrderStatuses.processing => (2, 'Preparation'),
      OrderStatuses.readyForDelivery => (3, 'Ready to ship'),
      OrderStatuses.riderAssigned => (4, 'Awaiting rider collection'),
      OrderStatuses.outForDelivery => (5, 'On the way'),
      OrderStatuses.awaitingConfirmation => (6, 'Awaiting receipt'),
      OrderStatuses.completed => (7, 'Completed'),
      OrderStatuses.delivered => (7, 'Delivered'),
      _ => null,
    };
    return Card(
      color: AppColors.cardWhite,
      elevation: 1,
      shadowColor: AppColors.primaryDark.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.inputBorder),
      ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORDER ${order.shortReference}',
                          style: const AppTypography.productTitle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Placed $orderDate',
                          style: const AppTypography.caption(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(),
                        textAlign: TextAlign.center,
                        style: const AppTypography.badge(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _detailLine(
                icon: Icons.schedule,
                value: order.deliveryTimeSlot.trim().isEmpty
                    ? 'Estimated dispatch dates are not guaranteed arrival times. Delivery depends on preparation and rider availability.'
                    : order.deliveryTimeSlot,
              ),
              const SizedBox(height: 8),
              _detailLine(
                icon: Icons.person_outline,
                label: 'Recipient',
                value: order.recipientName.isEmpty
                    ? 'Not provided'
                    : order.recipientName,
              ),
              if (order.riderId?.isNotEmpty == true &&
                  [
                    'Rider assigned',
                    'Out for Delivery',
                    'Awaiting Customer Confirmation',
                  ].contains(order.orderStatus)) ...[
                const SizedBox(height: 14),
                Text(
                  order.riderName.isEmpty
                      ? 'Rider assigned'
                      : 'Assigned rider: ${order.riderName}',
                ),
              ],
              if (preview != null) ...[
                const SizedBox(height: 12),
                _itemPreview(preview),
              ],
              const Divider(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${order.items.length} item(s)',
                      style: const AppTypography.supporting(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'RM ${order.totalAmount.toStringAsFixed(2)}',
                      textAlign: TextAlign.end,
                      style: const AppTypography.price(
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              if (progress case (final step, final label)) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: step / 7,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.primary,
                  backgroundColor: AppColors.softBlushEnd,
                  semanticsLabel: 'Order progress: $label',
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const AppTypography.caption(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine({
    required IconData icon,
    String? label,
    required String value,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Text(
                label,
                style: const AppTypography.caption(color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              value,
              style: const AppTypography.label(color: AppColors.primaryDark),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _itemPreview(Map<String, dynamic> item) {
    final quantity = num.tryParse(item['quantity'].toString()) ?? 1;
    final unitPrice = num.tryParse(item['unitPrice'].toString());
    final name = item['name']?.toString().trim();
    return Row(
      children: [
        OrderThumbnail(items: [item]),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            name == null || name.isEmpty ? 'Bouquet' : name,
            style: const AppTypography.supporting(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (unitPrice != null) ...[
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'RM ${(unitPrice * quantity).toStringAsFixed(2)}',
                textAlign: TextAlign.end,
                style: const AppTypography.price(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
