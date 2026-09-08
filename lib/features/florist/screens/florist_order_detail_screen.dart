import '../../../core/services/order_service.dart';
import 'package:flutter/material.dart';

import '../../../models/order_model.dart';
import 'order_materials_panel.dart';

class FloristOrderDetailScreen extends StatefulWidget {
  const FloristOrderDetailScreen({super.key, required this.order});

  final OrderModel order;

  @override
  State<FloristOrderDetailScreen> createState() =>
      _FloristOrderDetailScreenState();
}

class _FloristOrderDetailScreenState extends State<FloristOrderDetailScreen> {
  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.orderStatus;
  }

  String? get _nextStatus {
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
        return 'Mark Ready for Delivery';
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
      case 'Out for Delivery':
      case 'Completed':
      case 'Delivered':
        return 2;
      default:
        return 0;
    }
  }

  String get _statusTitle {
    switch (_currentStatus) {
      case 'Awaiting Preparation':
        return 'Order Received';
      case 'Processing':
        return 'Preparing Bouquet';
      case 'Ready for Delivery':
        return 'Bouquet Ready';
      case 'Out for Delivery':
        return 'Out for Delivery';
      case 'Completed':
      case 'Delivered':
        return 'Order Completed';
      default:
        return _currentStatus;
    }
  }

  String get _statusDescription {
    switch (_currentStatus) {
      case 'Awaiting Preparation':
        return 'Review the order before starting preparation.';
      case 'Processing':
        return 'The florist is currently preparing this order.';
      case 'Ready for Delivery':
        return 'The order is waiting for a rider to collect it.';
      case 'Out for Delivery':
        return 'A rider has collected and is delivering this order.';
      case 'Completed':
      case 'Delivered':
        return 'This order has been delivered successfully.';
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
      if (mounted) setState(() => _currentStatus = 'Cancelled');
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
                : 'Confirm that the bouquet is finished and ready for rider collection?',
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
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
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

      setState(() {
        _currentStatus = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'Processing'
                ? 'Order preparation started'
                : 'Order is ready for rider collection',
          ),
          backgroundColor: Colors.green,
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
          backgroundColor: Colors.red,
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
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          if (['Awaiting Preparation', 'Processing'].contains(_currentStatus))
            IconButton(
              tooltip: 'Cancel planned order',
              onPressed: _isUpdating ? null : _cancelOrder,
              icon: const Icon(Icons.cancel_outlined),
            ),
        ],
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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
                      Text('No items found for this order.'),
                    ],
                  ),
                ),
              )
            else
              ...items.map(_buildItemCard),

            const SizedBox(height: 20),
            _buildSectionTitle('Delivery Information'),
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

    return Row(
      children: [
        Expanded(
          child: Text(
            'Order #$shortId',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _statusColor().withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusTitle,
            style: TextStyle(
              color: _statusColor(),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Progress',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
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
                  label: 'Ready',
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
                    style: TextStyle(
                      color: _statusColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusDescription,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.access_time, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Planned bouquets require 1–3 business days. Check the delivery date and restock materials before marking ready.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      ? Colors.purple.shade50
                      : Colors.teal.shade50,
                  child: Icon(
                    isCustom ? Icons.auto_awesome : Icons.local_florist,
                    color: isCustom ? Colors.purple : Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['name'] ?? 'Item'} × $quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isCustom ? 'Custom bouquet' : 'Ready-made bouquet',
                        style: TextStyle(
                          color: isCustom ? Colors.purple : Colors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'RM ${unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            if (isCustom || stems.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'FLOWER STEMS',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
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
                          color: Colors.teal,
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CUSTOMER CARD MESSAGE',
                      style: TextStyle(
                        color: Colors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        Icon(icon, color: Colors.teal, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? 'Not provided' : value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTotal() {
    return Row(
      children: [
        const Text(
          'Order Total',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Text(
          'RM ${widget.order.totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.teal,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
    );
  }

  Widget? _buildBottomAction() {
    if (_nextStatus == null) {
      return null;
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isUpdating ? null : _confirmStatusUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor() {
    switch (_currentStatus) {
      case 'Awaiting Preparation':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Ready for Delivery':
        return Colors.green;
      case 'Out for Delivery':
        return Colors.deepPurple;
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
    final color = reached ? Colors.teal : Colors.grey.shade300;

    return SizedBox(
      width: 72,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: reached ? Colors.teal : Colors.white,
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
            style: TextStyle(
              color: reached ? Colors.teal : Colors.grey,
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
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
        color: reached ? Colors.teal : Colors.grey.shade300,
      ),
    );
  }
}
