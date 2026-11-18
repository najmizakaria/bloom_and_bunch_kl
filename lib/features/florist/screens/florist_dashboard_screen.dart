import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import '../../../core/utils/malaysia_time.dart';
import '../../../core/utils/order_tracking_display.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/order_model.dart';
import '../../customer/widgets/order_thumbnail.dart';
import 'florist_order_detail_screen.dart';

class FloristDashboardScreen extends StatefulWidget {
  const FloristDashboardScreen({
    super.key,
    required this.onOpenOrders,
    required this.onOpenProducts,
    this.watchOrders,
    this.watchFlowers,
  });

  final ValueChanged<String> onOpenOrders;
  final ValueChanged<int> onOpenProducts;
  final Stream<QuerySnapshot> Function()? watchOrders, watchFlowers;

  @override
  State<FloristDashboardScreen> createState() => _FloristDashboardScreenState();
}

class _FloristDashboardScreenState extends State<FloristDashboardScreen> {
  late final Stream<QuerySnapshot> _orders =
      widget.watchOrders?.call() ??
      FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots();
  late Stream<QuerySnapshot> _flowers = _watchFlowers();
  Stream<QuerySnapshot> _watchFlowers() =>
      widget.watchFlowers?.call() ??
      FirebaseFirestore.instance
          .collection('flowers')
          .orderBy(FieldPath.documentId)
          .limit(100)
          .snapshots();
  bool _isToday(DateTime date) {
    return isMalaysiaDay(date, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('Florist Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _orders,
        builder: (context, orderSnapshot) {
          if (orderSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load orders.\n${orderSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final orders =
              orderSnapshot.data?.docs.map((document) {
                return OrderModel.fromMap(
                  document.data() as Map<String, dynamic>,
                  document.id,
                );
              }).toList() ??
              [];

          final todayOrders = orders.where((order) {
            return _isToday(order.createdAt);
          }).toList();

          final newOrders = orders.where((order) {
            return order.orderStatus == 'Awaiting Preparation';
          }).toList();

          final preparingOrders = orders.where((order) {
            return order.orderStatus == 'Processing';
          }).toList();

          final readyOrders = orders.where((order) {
            return order.orderStatus == 'Ready for Delivery';
          }).toList();

          final activeOrders =
              orders.where((order) {
                return order.orderStatus == 'Awaiting Preparation' ||
                    order.orderStatus == 'Processing';
              }).toList()..sort((first, second) {
                return first.createdAt.compareTo(second.createdAt);
              });

          final OrderModel? nextOrder = activeOrders.isEmpty
              ? null
              : activeOrders.first;

          return StreamBuilder<QuerySnapshot>(
            stream: _flowers,
            builder: (context, flowerSnapshot) {
              final lowStockFlowers =
                  flowerSnapshot.data?.docs.where((document) {
                    final data = document.data() as Map<String, dynamic>;

                    final stock = (data['stockQuantity'] as num?)?.toInt() ?? 0;

                    final reserved =
                        (data['reservedQuantity'] as num?)?.toInt() ?? 0;
                    return stock - reserved <= 5;
                  }).toList() ??
                  [];
              final inventoryReady =
                  flowerSnapshot.hasData && !flowerSnapshot.hasError;
              final allClear =
                  inventoryReady &&
                  lowStockFlowers.isEmpty &&
                  preparingOrders.isEmpty;

              final orderShortcuts = [
                _DashboardStatCard(
                  title: 'New',
                  count: newOrders.length,
                  icon: Icons.notifications_none,
                  color: AppColors.statusNew,
                  onTap: () => widget.onOpenOrders('Awaiting Preparation'),
                ),
                _DashboardStatCard(
                  title: 'Preparing',
                  count: preparingOrders.length,
                  icon: Icons.local_florist_outlined,
                  color: AppColors.statusPreparing,
                  onTap: () => widget.onOpenOrders('Processing'),
                ),
                _DashboardStatCard(
                  title: 'Ready',
                  count: readyOrders.length,
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.statusReady,
                  onTap: () => widget.onOpenOrders('Ready for Delivery'),
                ),
                _DashboardStatCard(
                  title: 'Rider assigned',
                  count: orders
                      .where((order) => order.orderStatus == 'Rider assigned')
                      .length,
                  icon: Icons.delivery_dining,
                  color: AppColors.statusReady,
                  onTap: () => widget.onOpenOrders('Rider assigned'),
                ),
              ];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(_greeting(), style: const AppTypography.sectionTitle()),
                  const SizedBox(height: 10),

                  _TodaySummaryCard(totalOrders: todayOrders.length),

                  const SizedBox(height: 16),

                  const Text(
                    'Latest 100 orders',
                    style: AppTypography.sectionTitle(),
                  ),
                  const SizedBox(height: 10),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 10.0;
                      final singleColumn =
                          constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(12) > 18;
                      final tileWidth = singleColumn
                          ? constraints.maxWidth
                          : (constraints.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final shortcut in orderShortcuts)
                            SizedBox(width: tileWidth, child: shortcut),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _DashboardStatCard(
                    title: 'Low Stock (preview)',
                    count: inventoryReady ? lowStockFlowers.length : null,
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.statusLowStock,
                    onTap: () => widget.onOpenProducts(1),
                    inventoryBar: true,
                  ),

                  const SizedBox(height: 16),

                  if (!allClear) ...[
                    const Text(
                      'Attention Needed',
                      style: AppTypography.sectionTitle(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (flowerSnapshot.hasError)
                    TextButton(
                      onPressed: () =>
                          setState(() => _flowers = _watchFlowers()),
                      child: const Text('Inventory unavailable · Retry'),
                    )
                  else if (flowerSnapshot.connectionState ==
                      ConnectionState.waiting)
                    const LinearProgressIndicator(),

                  if (inventoryReady)
                    _AttentionCard(
                      lowStockCount: lowStockFlowers.length,
                      preparingCount: preparingOrders.length,
                      onOpenProducts: () => widget.onOpenProducts(1),
                    ),

                  const SizedBox(height: 12),

                  const Text('Up Next', style: AppTypography.sectionTitle()),
                  const SizedBox(height: 8),

                  if (nextOrder == null)
                    const _EmptyNextOrderCard()
                  else
                    _NextOrderCard(order: nextOrder),

                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning, Florist';
    }

    if (hour < 18) {
      return 'Good afternoon, Florist';
    }

    return 'Good evening, Florist';
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.totalOrders});

  final int totalOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.calendar_today,
              color: AppColors.onPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$totalOrders ${totalOrders == 1 ? 'order' : 'orders'} today',
              style: const AppTypography.productTitle(
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
    this.inventoryBar = false,
  });

  final String title;
  final int? count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool inventoryBar;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(inventoryBar ? 28 : 16);
    final label = Text(
      title,
      style: const AppTypography.caption(color: AppColors.textDark),
    );
    final amount = Text(
      '${count ?? '—'}',
      style: inventoryBar
          ? AppTypography.price(color: color)
          : AppTypography.total(color: color),
    );
    return Material(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: color.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              if (inventoryBar) ...[
                Expanded(child: label),
                const SizedBox(width: 8),
                amount,
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ] else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [amount, label],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.lowStockCount,
    required this.preparingCount,
    required this.onOpenProducts,
  });

  final int lowStockCount;
  final int preparingCount;
  final VoidCallback onOpenProducts;

  @override
  Widget build(BuildContext context) {
    if (lowStockCount == 0 && preparingCount == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFE7F2EC),
                child: Icon(
                  Icons.check,
                  color: AppColors.statusReady,
                  size: 18,
                ),
              ),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Everything looks great!',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          if (lowStockCount > 0)
            ListTile(
              onTap: onOpenProducts,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFBE8E6),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.statusLowStock,
                ),
              ),
              title: Text('$lowStockCount flowers have low stock'),
              subtitle: const Text('Stock quantity is 5 stems or fewer.'),
              trailing: const Icon(Icons.chevron_right),
            ),
          if (lowStockCount > 0 && preparingCount > 0) const Divider(height: 1),
          if (preparingCount > 0)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF1D9),
                child: Icon(
                  Icons.local_florist_outlined,
                  color: AppColors.statusPreparing,
                ),
              ),
              title: Text('$preparingCount orders are being prepared'),
              subtitle: const Text('Check whether any bouquet is ready.'),
            ),
        ],
      ),
    );
  }
}

class _NextOrderCard extends StatelessWidget {
  const _NextOrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final dispatch = order.earlyDispatchDate ?? order.estimatedDispatchDate;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FloristOrderDetailScreen(order: order),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OrderThumbnail(
                    items: order.items
                        .where((item) => item['type'] != 'addon')
                        .toList(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORDER ${order.shortReference}',
                          style: const AppTypography.label(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.recipientName.isEmpty
                              ? 'Recipient not provided'
                              : order.recipientName,
                          style: const AppTypography.productTitle(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusBadge(status: order.orderStatus),
                  Text(
                    'Dispatch: ${dispatch == null || dispatch.isEmpty ? 'To be confirmed' : trackingDate(dispatch)}',
                    style: const AppTypography.caption(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              if (order.requiresPrepTime) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Preparation required',
                      style: AppTypography.label(color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 40),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FloristOrderDetailScreen(order: order),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;

    switch (status) {
      case 'Awaiting Preparation':
        color = AppColors.statusNew;
        break;
      case 'Processing':
        color = AppColors.statusPreparing;
        break;
      case 'Ready for Delivery':
        color = AppColors.statusReady;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status == 'Ready for Delivery' ? 'Ready to ship' : status,
        style: AppTypography.badge(color: color),
      ),
    );
  }
}

class _EmptyNextOrderCard extends StatelessWidget {
  const _EmptyNextOrderCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.task_alt, size: 48, color: AppColors.primaryDark),
              SizedBox(height: 12),
              Text('No active orders', style: AppTypography.productTitle()),
              SizedBox(height: 4),
              Text(
                'New customer orders will appear here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
