import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import '../../../core/widgets/retry_stream_builder.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/malaysia_time.dart';
import '../../../core/services/order_service.dart';
import '../../../core/widgets/delivery_progress.dart';
import '../../../core/constants/fulfillment_constants.dart';
import '../../support/order_support.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final List<String> relatedOrderIds;
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.relatedOrderIds = const [],
  });
  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _confirming = false;
  Future<void> _confirmReceived() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      await OrderService().transition(widget.orderId, 'confirmReceived');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(OrderService.message(e))));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _stream = _watch();
  Stream<DocumentSnapshot<Map<String, dynamic>>> _watch() =>
      FirebaseFirestore.instance.doc('orders/${widget.orderId}').snapshots();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const PageBackButton(),
      centerTitle: false,
      title: const Text('Track order'),
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load this order.'),
                OutlinedButton(
                  onPressed: () => setState(() => _stream = _watch()),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (!s.data!.exists) {
          return const Center(child: Text('Order not found.'));
        }
        final d = s.data!.data()!,
            status = OrderStatuses.normalize(
              (s.data!.data()!['orderStatus'] ?? 'Pending').toString(),
            );
        final id = widget.orderId;
        final updated = (d['updatedAt'] as Timestamp?)?.toDate();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Order #${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (d['orderMode'] == 'demo')
              const Text('Demo order — no real payment or delivery.'),
            if (s.data!.metadata.isFromCache)
              const Text(
                'Showing saved information. Reconnecting for updates…',
              ),
            if (updated != null) Text('Last updated ${malaysiaTime(updated)}'),
            const SizedBox(height: 16),
            DeliveryProgress(
              status: status,
              receiptConfirmed: d['customerAcceptedAt'] is Timestamp,
              fulfillmentType: (d['fulfillmentType'] ?? 'custom').toString(),
            ),
            if (status == OrderStatuses.awaitingConfirmation &&
                d['customerId'] == FirebaseAuth.instance.currentUser?.uid)
              ReceiptConfirmation(
                busy: _confirming,
                hasOpenIssue:
                    d['support'] is Map && d['support']['status'] == 'open',
                onConfirm: _confirmReceived,
              ),
            if (d['estimatedDispatchDate'] != null)
              Text(
                'Estimated dispatch: ${d['estimatedDispatchDate']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            Text(
              (d['deliveryTimeSlot'] ??
                      'Contact the store for delivery timing.')
                  .toString(),
            ),
            if (!OrderStatuses.isPast(status))
              Text(
                d['riderId'] == null
                    ? 'No rider assigned yet. Contact the store if your delivery is time-sensitive.'
                    : 'A rider has accepted your delivery.',
              ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Delivering to'),
                subtitle: Text(
                  '${d['recipientName'] ?? ''}\n${d['deliveryAddress'] ?? ''}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Total RM ${((d['totalAmount'] as num?) ?? 0).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (d['deliveryFee'] != null)
              Text(
                'Includes delivery RM ${(d['deliveryFee'] as num).toStringAsFixed(2)}',
              ),
            Text(switch (d['paymentStatus']) {
              'paid' => 'Payment confirmed by the store',
              'pending' => 'Payment awaiting store confirmation',
              'not_required' => 'No payment collected for this demo',
              _ => 'Payment: contact the store',
            }),
            if (d['paymentInstructions'] != null)
              Text(d['paymentInstructions'].toString()),
            if (d['checkoutGroupId'] != null)
              RetryStreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                key: ValueKey(
                  'related-${d['customerId']}-${d['checkoutGroupId']}',
                ),
                watch: () => FirebaseFirestore.instance
                    .collection('orders')
                    .where('customerId', isEqualTo: d['customerId'])
                    .where('checkoutGroupId', isEqualTo: d['checkoutGroupId'])
                    .limit(2)
                    .snapshots(),
                builder: (context, group) => Column(
                  children: [
                    if (group.hasError)
                      const Text(
                        'Related deliveries could not be loaded. Reopen this order to retry.',
                      ),
                    for (final other
                        in group.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                      if (other.id != widget.orderId)
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderTrackingScreen(orderId: other.id),
                            ),
                          ),
                          child: Text(
                            'Track your other delivery · ${other.data()['orderStatus']}',
                          ),
                        ),
                  ],
                ),
              ),
            ExpansionTile(
              initiallyExpanded: true,
              title: const Text('Delivery timeline'),
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .doc('orders/${widget.orderId}')
                      .collection('events')
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, events) {
                    if (events.hasError) {
                      return const ListTile(
                        title: Text(
                          'Activity is unavailable. Try reopening this order.',
                        ),
                      );
                    }
                    if (!events.hasData) return const LinearProgressIndicator();
                    if (events.data!.docs.isEmpty) {
                      return const ListTile(
                        title: Text(
                          'No activity recorded for this older order.',
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final e in events.data!.docs)
                          ListTile(
                            title: Text(
                              OrderStatuses.label(
                                e.data()['status'].toString(),
                                receiptConfirmed:
                                    d['customerAcceptedAt'] is Timestamp,
                              ),
                            ),
                            subtitle: Text(
                              e.data()['createdAt'] is Timestamp
                                  ? malaysiaTime(
                                      (e.data()['createdAt'] as Timestamp)
                                          .toDate(),
                                    )
                                  : 'Updating…',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            OrderSupportPanel(orderId: widget.orderId, order: d),
          ],
        );
      },
    ),
  );
}
