import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../models/order_model.dart';
import 'florist_order_detail_screen.dart';

class FloristDashboardScreen extends StatelessWidget {
  const FloristDashboardScreen({
    super.key,
    required this.onOpenOrders,
    required this.onOpenProducts,
  });

  final VoidCallback onOpenOrders;
  final VoidCallback onOpenProducts;

  bool _isToday(DateTime date) {
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _shortOrderId(String orderId) {
    if (orderId.length <= 8) {
      return orderId.toUpperCase();
    }

    return orderId.substring(0, 8).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Florist Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
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

          final completedToday = todayOrders.where((order) {
            return order.orderStatus == 'Delivered';
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
            stream: FirebaseFirestore.instance
                .collection('flowers')
                .snapshots(),
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

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _greeting(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Here is what needs your attention today.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  _TodaySummaryCard(
                    totalOrders: todayOrders.length,
                    completedOrders: completedToday.length,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Order Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _DashboardStatCard(
                        title: 'New',
                        count: newOrders.length,
                        icon: Icons.notifications_none,
                        color: AppColors.statusNew,
                        onTap: onOpenOrders,
                      ),
                      _DashboardStatCard(
                        title: 'Preparing',
                        count: preparingOrders.length,
                        icon: Icons.local_florist_outlined,
                        color: AppColors.statusPreparing,
                        onTap: onOpenOrders,
                      ),
                      _DashboardStatCard(
                        title: 'Ready',
                        count: readyOrders.length,
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.statusReady,
                        onTap: onOpenOrders,
                      ),
                      _DashboardStatCard(
                        title: 'Low Stock',
                        count: lowStockFlowers.length,
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.statusLowStock,
                        onTap: onOpenProducts,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Attention Needed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _AttentionCard(
                    lowStockCount: lowStockFlowers.length,
                    preparingCount: preparingOrders.length,
                    onOpenProducts: onOpenProducts,
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Up Next',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (nextOrder == null)
                    const _EmptyNextOrderCard()
                  else
                    _NextOrderCard(
                      order: nextOrder,
                      shortOrderId: _shortOrderId(nextOrder.orderId),
                    ),

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
  const _TodaySummaryCard({
    required this.totalOrders,
    required this.completedOrders,
  });

  final int totalOrders;
  final int completedOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.calendar_today, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Orders",
                  style: AppTypography.supporting(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalOrders orders',
                  style: const AppTypography.display(color: Colors.white),
                ),
                Text(
                  '$completedOrders completed today',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
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
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(icon, color: color, size: 22),
                ),
              ),
              const Spacer(),
              Text('$count', style: AppTypography.display(color: color)),
              Text(
                title,
                style: const AppTypography.label(color: AppColors.textDark),
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
      return const Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Color(0xFFE7F2EC),
            child: Icon(Icons.check, color: AppColors.statusReady),
          ),
          title: Text('Everything looks good'),
          subtitle: Text('There are no urgent warnings right now.'),
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
  const _NextOrderCard({required this.order, required this.shortOrderId});

  final OrderModel order;
  final String shortOrderId;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'ORDER #$shortOrderId',
                    style: const AppTypography.label(color: AppColors.primary),
                  ),
                  const Spacer(),
                  _StatusBadge(status: order.orderStatus),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                order.recipientName.isEmpty
                    ? 'Recipient not provided'
                    : order.recipientName,
                style: const AppTypography.sectionTitle(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.deliveryTimeSlot)),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
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
      child: Text(status, style: AppTypography.badge(color: color)),
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
