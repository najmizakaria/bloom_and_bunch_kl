import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import '../../../core/widgets/live_order_detail.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import '../../../core/services/order_service.dart';
import 'package:flutter/material.dart';

import '../../../models/order_model.dart';
import 'order_materials_panel.dart';
import '../../customer/screens/message_card_screen.dart';
import '../../support/order_rider_assignment.dart';

class FloristOrderDetailScreen extends StatelessWidget {
  const FloristOrderDetailScreen({super.key, required this.order, this.watch});
  final OrderModel order;
  final OrderWatch? watch;
  @override
  Widget build(BuildContext context) => LiveOrderDetail(
    orderId: order.orderId,
    watch: watch,
    builder: (latest) => _FloristOrderDetailContent(order: latest),
  );
}

class _FloristOrderDetailContent extends StatefulWidget {
  const _FloristOrderDetailContent({required this.order});

  final OrderModel order;

  @override
  State<_FloristOrderDetailContent> createState() =>
      _FloristOrderDetailContentState();
}

class _FloristOrderDetailContentState
    extends State<_FloristOrderDetailContent> {
  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.orderStatus;
  }

  @override
  void didUpdateWidget(covariant _FloristOrderDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _currentStatus = widget.order.orderStatus;
  }

  String? get _nextStatus {
    if (widget.order.hasOpenIssue || widget.order.paymentOnHold) return null;
    switch (_currentStatus) {
      case 'Awaiting Preparation':
        return 'Processing';
      case 'Processing':
        return 'Ready for Delivery';
      default:
        return null;
    }
  }

  String get _actionLabel {
    switch (_currentStatus) {
      case 'Awaiting Preparation':
        return 'Start Preparing';
      case 'Processing':
        return 'Mark Ready to ship';
      default:
        return '';
    }
  }

  IconData get _actionIcon {
    switch (_currentStatus) {
      case 'Awaiting Preparation':
        return Icons.local_florist_outlined;
      case 'Processing':
        return Icons.inventory_2_outlined;
      default:
        return Icons.check;
    }
  }

  int get _currentStep {
    switch (_currentStatus) {
      case 'Awaiting Preparation':
        return 0;
      case 'Processing':
        return 1;
      case 'Ready for Delivery':
      case 'Rider assigned':
      case 'Out for Delivery':
      case 'Awaiting Customer Confirmation':
      case 'Completed':
      case 'Delivered':
        return 2;
      default:
        return 0;
    }
  }

  String get _statusTitle {
    if (widget.order.paymentOnHold && _currentStatus != 'Cancelled') {
      return 'Awaiting Payment';
    }
    switch (_currentStatus) {
      case 'Awaiting Preparation':
        return 'Order Received';
      case 'Processing':
        return 'Preparing Bouquet';
      case 'Ready for Delivery':
        return 'Ready to ship';
      case 'Rider assigned':
        return 'Rider assigned';
      case 'Out for Delivery':
        return 'Delivering';
      case 'Awaiting Customer Confirmation':
        return 'Awaiting Customer Receipt';
      case 'Completed':
        return widget.order.receiptConfirmed
            ? 'Receipt Confirmed'
            : 'Completed (Legacy)';
      case 'Delivered':
        return 'Delivered (Legacy)';
      default:
        return _currentStatus;
    }
  }

  String get _statusDescription {
    if (widget.order.paymentOnHold && _currentStatus != 'Cancelled') {
      return 'Preparation and rider collection are on hold until payment is verified.';
    }
    switch (_currentStatus) {
      case 'Awaiting Preparation':
        return 'Review the order before starting preparation.';
      case 'Processing':
        return 'The florist is currently preparing this order.';
      case 'Ready for Delivery':
        return 'The order is packed and awaiting a rider. Check the handoff details below.';
      case 'Rider assigned':
        return 'A rider is assigned. Collection has not been confirmed yet.';
      case 'Out for Delivery':
        return 'A rider has collected and is delivering this order.';
      case 'Awaiting Customer Confirmation':
        return 'The rider recorded delivery. The customer must confirm receipt.';
      case 'Completed':
        return widget.order.receiptConfirmed
            ? 'The customer confirmed receiving this order.'
            : 'Completed under the older workflow. Customer receipt confirmation was not recorded.';
      case 'Delivered':
        return 'Delivery was recorded in the older workflow. Receipt confirmation was not recorded.';
      default:
        return 'Check the current order status.';
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this planned order?'),
        content: const Text('Its material reservations will be released.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _isUpdating = true);
    try {
      await OrderService().transition(widget.order.orderId, 'cancel');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(OrderService.message(e))));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _confirmStatusUpdate() async {
    final newStatus = _nextStatus;

    if (newStatus == null || _isUpdating) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_actionLabel),
          content: Text(
            newStatus == 'Processing'
                ? 'Start preparing this customer order?'
                : 'Confirm that the bouquet, add-ons and message card are packed and ready for rider collection?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (mounted && confirmed == true) {
      await _updateStatus(newStatus);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await OrderService().transition(
        widget.order.orderId,
        newStatus == 'Processing' ? 'prepare' : 'ready',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'Processing'
                ? 'Order preparation started'
                : 'Ready to ship. Check rider availability below.',
          ),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update order: ${OrderService.message(error)}',
          ),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order.items;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('Order Details'),
        actions: [
          if (['Awaiting Preparation', 'Processing'].contains(_currentStatus))
            IconButton(
              tooltip: 'Cancel planned order',
              onPressed:
                  _isUpdating ||
                      widget.order.hasOpenIssue ||
                      widget.order.paymentOnHold
                  ? null
                  : _cancelOrder,
              icon: const Icon(Icons.cancel_outlined),
            ),
        ],
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      bottomNavigationBar: _buildBottomAction(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeading(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            OrderRiderAssignment(order: widget.order),
            if (widget.order.riderId?.isNotEmpty == true &&
                [
                  'Rider assigned',
                  'Out for Delivery',
                  'Awaiting Customer Confirmation',
                ].contains(_currentStatus))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  widget.order.riderName.isEmpty
                      ? 'Rider assigned'
                      : 'Assigned rider: ${widget.order.riderName}',
                ),
              ),
            if (widget.order.hasOpenIssue)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'An open issue pauses order transitions. Contact the administrator.',
                ),
              ),
            if (['Awaiting Preparation', 'Processing'].contains(_currentStatus))
              OrderMaterialsPanel(order: widget.order),
            const SizedBox(height: 16),

            if (widget.order.requiresPrepTime) _buildPreparationWarning(),

            const SizedBox(height: 20),
            _buildSectionTitle('What to Prepare'),
            const SizedBox(height: 10),

            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey),
                      SizedBox(width: 10),
                      Expanded(child: Text('No items found for this order.')),
                    ],
                  ),
                ),
              )
            else
              ...items.map(_buildItemCard),

            const SizedBox(height: 20),
            _buildSectionTitle('Delivery Information'),
            if (widget.order.scheduledDeliveryDate != null)
              Text('Requested delivery: ${widget.order.scheduledDeliveryDate}'),
            if (widget.order.messageCard != null) ...[
              const SizedBox(height: 16),
              _buildSectionTitle('Message card to include'),
              MessageCardPreview(
                designName: widget.order.messageCard!['designName'] as String,
                imageUrl:
                    widget.order.messageCard!['imageUrl'] as String? ?? '',
                message: widget.order.messageCard!['message'] as String,
                senderName: widget.order.messageCard!['senderName'] as String,
              ),
            ],
            const SizedBox(height: 10),
            _buildDeliveryCard(),

            const SizedBox(height: 20),
            _buildOrderTotal(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeading() {
    final fullId = widget.order.orderId;
    final shortId = fullId.length <= 8
        ? fullId.toUpperCase()
        : fullId.substring(0, 8).toUpperCase();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        Text('Order #$shortId', style: const AppTypography.sectionTitle()),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _statusColor().withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusTitle,
            style: AppTypography.badge(color: _statusColor()),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Progress', style: AppTypography.productTitle()),
            const SizedBox(height: 18),
            Row(
              children: [
                _ProgressStep(
                  label: 'Received',
                  icon: Icons.receipt_long_outlined,
                  reached: _currentStep >= 0,
                  active: _currentStep == 0,
                ),
                _ProgressLine(reached: _currentStep >= 1),
                _ProgressStep(
                  label: 'Preparing',
                  icon: Icons.local_florist_outlined,
                  reached: _currentStep >= 1,
                  active: _currentStep == 1,
                ),
                _ProgressLine(reached: _currentStep >= 2),
                _ProgressStep(
                  label: 'Ready to ship',
                  icon: Icons.inventory_2_outlined,
                  reached: _currentStep >= 2,
                  active: _currentStep == 2,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor().withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusTitle,
                    style: AppTypography.label(color: _statusColor()),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusDescription,
                    style: AppTypography.supporting(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreparationWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.access_time, color: AppColors.primaryDark),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Check the requested delivery date and restock materials before marking ready. Future deliveries stay unavailable to riders until their scheduled date.',
              style: AppTypography.label(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final isCustom = item['type'] == 'custom';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
    final cardNote = (item['cardNote'] ?? '').toString();

    final rawStems = item['customStems'] ?? item['recipeStems'];
    final Map<String, dynamic> stems;

    if (rawStems is Map) {
      stems = Map<String, dynamic>.from(rawStems);
    } else {
      stems = {};
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: isCustom
                      ? AppColors.secondarySurface
                      : AppColors.inputFill,
                  child: Icon(
                    isCustom ? Icons.auto_awesome : Icons.local_florist,
                    color: isCustom ? AppColors.primaryDark : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['name'] ?? 'Item'} × $quantity',
                        style: const AppTypography.productTitle(),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['type'] == 'addon'
                            ? 'Add-on to pack'
                            : isCustom
                            ? 'Custom bouquet'
                            : 'Ready-made bouquet',
                        style: AppTypography.badge(
                          color: isCustom
                              ? AppColors.primaryDark
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Text(
              'RM ${unitPrice.toStringAsFixed(2)}',
              style: const AppTypography.price(),
            ),
            if (isCustom || stems.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'FLOWER STEMS',
                style: AppTypography.badge(color: Colors.grey),
              ),
              const SizedBox(height: 8),

              if (stems.isEmpty)
                const Text(
                  'No stems recorded',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...stems.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_florist_outlined,
                          size: 17,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ((item['customStemNames'] as Map?)?[entry.key] ??
                                    entry.key)
                                .toString(),
                          ),
                        ),
                        Text(
                          '× ${entry.value}',
                          style: const AppTypography.label(),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 10),
              _buildItemDetail(
                'Wrapper',
                (item['wrapper'] ?? 'Not selected').toString(),
              ),
              _buildItemDetail(
                'Ribbon',
                (item['ribbon'] ?? 'Not selected').toString(),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CUSTOMER CARD MESSAGE',
                      style: AppTypography.badge(color: AppColors.primary),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      cardNote.isEmpty ? 'No message provided' : '"$cardNote"',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontStyle: cardNote.isEmpty
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value, style: const AppTypography.label())),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDeliveryRow(
              Icons.schedule,
              'Delivery slot',
              widget.order.deliveryTimeSlot,
            ),
            const Divider(height: 24),
            _buildDeliveryRow(
              Icons.person_outline,
              'Recipient',
              widget.order.recipientName,
            ),
            const Divider(height: 24),
            _buildDeliveryRow(
              Icons.phone_outlined,
              'Phone',
              widget.order.recipientPhone,
            ),
            const Divider(height: 24),
            _buildDeliveryRow(
              Icons.location_on_outlined,
              'Address',
              widget.order.deliveryAddress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const AppTypography.caption(color: Colors.grey),
              ),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? 'Not provided' : value,
                style: const AppTypography.label(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTotal() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        const Text('Order Total', style: AppTypography.productTitle()),
        Text(
          'RM ${widget.order.totalAmount.toStringAsFixed(2)}',
          style: const AppTypography.total(color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const AppTypography.sectionTitle());
  }

  Widget? _buildBottomAction() {
    if (_nextStatus == null) {
      return null;
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(color: Colors.white),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: ElevatedButton.icon(
            onPressed: _isUpdating ? null : _confirmStatusUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            icon: _isUpdating
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_actionIcon),
            label: Text(
              _isUpdating ? 'Updating...' : _actionLabel,
              style: const AppTypography.label(),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor() {
    switch (_currentStatus) {
      case 'Awaiting Preparation':
        return AppColors.primaryDark;
      case 'Processing':
        return AppColors.primaryDark;
      case 'Ready for Delivery':
        return AppColors.primaryDark;
      case 'Out for Delivery':
        return AppColors.primaryDark;
      case 'Completed':
      case 'Delivered':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.icon,
    required this.reached,
    required this.active,
  });

  final String label;
  final IconData icon;
  final bool reached;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = reached ? AppColors.primary : Colors.grey.shade300;

    return Flexible(
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: reached ? AppColors.primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: active ? 3 : 2),
              ),
              child: Icon(
                reached ? Icons.check : icon,
                color: reached ? Colors.white : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.caption(
                color: reached ? AppColors.primary : Colors.grey,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.reached});

  final bool reached;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 23),
        color: reached ? AppColors.primary : Colors.grey.shade300,
      ),
    );
  }
}
