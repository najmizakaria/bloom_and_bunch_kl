import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../support/order_rider_assignment.dart';
import '../../core/constants/fulfillment_constants.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/order_service.dart';
import '../../core/utils/malaysia_time.dart';
import '../../core/widgets/action_confirmation.dart';
import '../../core/widgets/firestore_page.dart';
import '../../models/order_model.dart';
import '../florist/screens/order_materials_panel.dart';
import 'admin_widgets.dart';
import '../customer/screens/message_card_screen.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  const AdminOrderDetailScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  bool _busy = false;
  late final _order = FirebaseFirestore.instance
      .doc('orders/${widget.orderId}')
      .snapshots();
  Future<void> _action(String title, Future<void> Function() run) async {
    if (!await confirmAction(
          context,
          title: title,
          message: title.contains('manual payment')
              ? 'Only confirm after checking that the store actually received payment. This records receipt; it does not charge the customer.'
              : 'Apply this action to the order? Existing payment and delivery checks will still apply.',
          action: 'Confirm',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    await adminAction(context, run);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resolve() async {
    final controller = TextEditingController();
    final response = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Respond and resolve issue'),
        content: TextField(
          controller: controller,
          maxLength: 1000,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Resolution for the customer',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (response != null && response.isNotEmpty && mounted) {
      await _action('Resolve this issue?', () async {
        await AdminService().call('resolveOrderIssue', {
          'orderId': widget.orderId,
          'response': response,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Order details')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _order,
      builder: (context, s) {
        if (s.hasError) {
          return const Center(
            child: Text('Cannot load this order. Reopen it to retry.'),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final data = s.data!.data();
        if (data == null) {
          return const Center(child: Text('Order no longer exists.'));
        }
        final order = OrderModel.fromMap(data, widget.orderId);
        Widget button(String label, Future<void> Function() run) =>
            FilledButton(
              onPressed: _busy ? null : () => _action(label, run),
              child: Text(label),
            );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SelectableText(
              'Order ${widget.orderId}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              OrderStatuses.label(
                order.orderStatus,
                receiptConfirmed: order.receiptConfirmed,
              ),
            ),
            Text(
              '${FulfillmentTypes.customerLabel(order.fulfillmentType)} · RM ${order.totalAmount.toStringAsFixed(2)}',
            ),
            const Divider(),
            Text('Recipient: ${order.recipientName} · ${order.recipientPhone}'),
            OrderRiderAssignment(order: order),
            Text(order.deliveryAddress),
            if (order.deliveryNote.isNotEmpty)
              Text('Note: ${order.deliveryNote}'),
            Text('Florist: ${order.floristId ?? 'Not assigned'}'),
            Text(
              'Rider: ${data['riderName'] ?? order.riderId ?? 'Not assigned'}',
            ),
            const Divider(),
            Text(
              'Payment: ${order.paymentStatus.isEmpty ? 'Unknown' : order.paymentStatus} · ${order.orderMode.isEmpty ? 'Legacy' : order.orderMode}',
            ),
            if (order.orderMode == 'toyyibpay_sandbox')
              const Text(
                'ToyyibPay sandbox: test transaction, not live revenue.',
              ),
            if (data['paymentId'] != null)
              SelectableText('Payment reference: ${data['paymentId']}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (order.orderMode == 'manual' &&
                    order.paymentStatus != 'paid' &&
                    order.orderStatus != OrderStatuses.cancelled)
                  button('Confirm manual payment received', () async {
                    await AdminService().call('confirmManualPayment', {
                      'orderId': widget.orderId,
                    });
                  }),
                if (order.orderMode == 'toyyibpay_sandbox')
                  button('Verify sandbox payment', () async {
                    final p = await AdminService().call('adminCheckPayment', {
                      'orderId': widget.orderId,
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Verified payment status: ${p['status']}',
                          ),
                        ),
                      );
                    }
                  }),
                if (!order.paymentOnHold &&
                    [
                      OrderStatuses.awaitingPreparation,
                      OrderStatuses.legacyPending,
                    ].contains(order.orderStatus))
                  button(
                    'Start preparation',
                    () => OrderService().transition(widget.orderId, 'prepare'),
                  ),
                if (!order.paymentOnHold &&
                    order.orderStatus == OrderStatuses.processing)
                  button(
                    'Mark Ready to ship',
                    () => OrderService().transition(widget.orderId, 'ready'),
                  ),
                if ([
                  OrderStatuses.awaitingPreparation,
                  OrderStatuses.legacyPending,
                  OrderStatuses.processing,
                ].contains(order.orderStatus))
                  button(
                    'Cancel order',
                    () => OrderService().transition(widget.orderId, 'cancel'),
                  ),
              ],
            ),
            const Divider(),
            Text('Items', style: Theme.of(context).textTheme.titleLarge),
            if (order.scheduledDeliveryDate != null)
              Text('Requested delivery: ${order.scheduledDeliveryDate}'),
            if (order.messageCard != null)
              MessageCardPreview(
                designName: order.messageCard!['designName'] as String,
                imageUrl: order.messageCard!['imageUrl'] as String? ?? '',
                message: order.messageCard!['message'] as String,
                senderName: order.messageCard!['senderName'] as String,
              ),
            for (final item in order.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${item['quantity'] ?? 1} × ${item['name'] ?? 'Bouquet'}',
                ),
                subtitle: Text(
                  '${item['fulfillmentType'] ?? order.fulfillmentType}${(item['cardNote'] ?? '').toString().isEmpty ? '' : '\nCard: ${item['cardNote']}'}',
                ),
              ),
            OrderMaterialsPanel(order: order),
            const Divider(),
            Text(
              'Recorded timeline',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final entry in {
              'createdAt': 'Order placed',
              'paidAt': 'Payment received',
              'preparationStartedAt': 'Preparation started',
              'readyAt': 'Ready to ship',
              'assignedAt': 'Rider assigned',
              'collectedAt': 'Collected by rider',
              'acceptedAt': 'Rider accepted',
              'deliveredAt': 'Rider marked delivered',
              'customerAcceptedAt': 'Customer confirmed receipt',
              'cancelledAt': 'Cancelled',
            }.entries)
              Text(
                '${entry.value}: ${data[entry.key] is Timestamp ? malaysiaTime((data[entry.key] as Timestamp).toDate()) : 'Not recorded'}',
              ),
            if (data['support'] is Map) ...[
              const Divider(),
              Text('Support · ${data['support']['status']}'),
              Text('${data['support']['comment'] ?? ''}'),
              Text(
                'Response: ${data['support']['response'] ?? 'Awaiting response'}',
              ),
              if (order.hasOpenIssue)
                FilledButton(
                  onPressed: _busy ? null : _resolve,
                  child: const Text('Respond and resolve'),
                ),
            ],
            if (data['feedback'] is Map) ...[
              const Divider(),
              Text('Customer feedback: ${data['feedback']['rating']}/5'),
              Text('${data['feedback']['comment'] ?? ''}'),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  openAdminPage(context, _OrderEvents(orderId: widget.orderId)),
              child: const Text('View order event history'),
            ),
          ],
        );
      },
    ),
  );
}

class _OrderEvents extends StatelessWidget {
  const _OrderEvents({required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Order event history')),
    body: FirestorePage(
      query: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('events')
          .orderBy('createdAt', descending: true),
      emptyMessage: 'No recorded events.',
      builder: (context, docs) => ListView(
        children: docs
            .map(
              (d) => ListTile(
                title: Text('${d.data()['status']}'),
                subtitle: Text(
                  d.data()['createdAt'] is Timestamp
                      ? malaysiaTime(
                          (d.data()['createdAt'] as Timestamp).toDate(),
                        )
                      : 'Time not recorded',
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}
