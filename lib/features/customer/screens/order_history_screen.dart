import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/cart_provider.dart';
import '../../../core/services/reorder_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/order_thumbnail.dart';
import 'order_tracking_screen.dart';
import 'cart_screen.dart';
import '../../../core/widgets/firestore_page.dart';

String _friendlyStatus(String raw) {
  return switch (raw) {
    'Awaiting Preparation' || 'Pending' => 'Received',
    'Processing' => 'Assembling',
    'Ready for Delivery' => 'Ready for collection',
    'Completed' => 'Completed',
    _ => raw,
  };
}

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  Query<Map<String, dynamic>> _query() {
    final statuses = _showPast
        ? ['Delivered', 'Completed', 'Cancelled']
        : [
            'Awaiting Preparation',
            'Pending',
            'Processing',
            'Ready for Delivery',
            'Out for Delivery',
            'Awaiting Customer Confirmation',
          ];
    final selected = statuses
        .where(
          (s) => _statusFilter == 'All' || _friendlyStatus(s) == _statusFilter,
        )
        .toList();
    return FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .where(
          'orderStatus',
          whereIn: selected.isEmpty ? ['__no_status__'] : selected,
        )
        .orderBy('createdAt', descending: true);
  }

  bool _showPast = false;
  String _statusFilter = 'All';

  Future<void> _orderAgain(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final cart = context.read<CartProvider>();
    try {
      var added = 0, unavailable = 0;
      for (final raw in data['items'] as List? ?? []) {
        if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
        try {
          await ReorderService.add(cart, Map<String, dynamic>.from(raw as Map));
          added++;
        } catch (_) {
          unavailable++;
        }
      }
      if (mounted && FirebaseAuth.instance.currentUser?.uid == uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$added item(s) added at current prices${unavailable > 0 ? '; $unavailable could not be added' : ''}.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Some items are no longer available.')),
        );
      }
    }
  }

  Color _statusColor(String raw) {
    return switch (raw) {
      'Completed' || 'Delivered' => AppColors.success,
      'Cancelled' => AppColors.error,
      'Out for Delivery' || 'Ready for Delivery' => AppColors.primary,
      _ => AppColors.warning,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text('Your orders'),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
            icon: Badge(
              isLabelVisible: context.watch<CartProvider>().itemCount > 0,
              label: Text('${context.watch<CartProvider>().itemCount}'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _segment(
                          'Active',
                          !_showPast,
                          () => setState(() {
                            _showPast = false;
                            _statusFilter = 'All';
                          }),
                        ),
                      ),
                      Expanded(
                        child: _segment(
                          'Past',
                          _showPast,
                          () => setState(() {
                            _showPast = true;
                            _statusFilter = 'All';
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_showPast),
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                        ),
                        items:
                            const [
                                  'All',
                                  'Received',
                                  'Assembling',
                                  'Ready for collection',
                                  'Out for Delivery',
                                  'Awaiting Customer Confirmation',
                                  'Completed',
                                  'Delivered',
                                  'Cancelled',
                                ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) =>
                            setState(() => _statusFilter = value ?? 'All'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FirestorePage(
              key: ValueKey('$_showPast/$_statusFilter'),
              query: _query(),
              emptyMessage: _showPast
                  ? 'No past orders match this filter.'
                  : 'No active orders match this filter.',
              builder: (context, docs) {
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final rawStatus = (data['orderStatus'] ?? 'Pending')
                        .toString();
                    final status = _friendlyStatus(rawStatus);
                    final total =
                        (data['totalAmount'] as num?)?.toDouble() ?? 0;
                    final items = data['items'] as List<dynamic>? ?? const [];
                    final createdAt = (data['createdAt'] as Timestamp?)
                        ?.toDate();
                    final orderLabel = doc.id.length > 8
                        ? doc.id.substring(doc.id.length - 8).toUpperCase()
                        : doc.id.toUpperCase();

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '#$orderLabel',
                                        style: const AppTypography.label(),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        createdAt == null
                                            ? 'Date unavailable'
                                            : DateFormat(
                                                'd MMM yyyy',
                                              ).format(createdAt),
                                        style: const AppTypography.caption(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      rawStatus,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: AppTypography.badge(
                                      color: _statusColor(rawStatus),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 28),
                            Row(
                              children: [
                                OrderThumbnail(items: items),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${items.length} item${items.length == 1 ? '' : 's'}',
                                        style: const AppTypography.label(),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'RM ${total.toStringAsFixed(2)}',
                                        style: const AppTypography.price(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                if (_showPast) ...[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _orderAgain(data),
                                      icon: const Icon(
                                        Icons.replay_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Order again'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => OrderTrackingScreen(
                                          orderId: doc.id,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _showPast
                                          ? 'Order details'
                                          : 'Track order',
                                    ),
                                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.label(
            color: selected ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
