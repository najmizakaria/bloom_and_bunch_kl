import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'message_card_screen.dart';

class CheckoutReceiptScreen extends StatefulWidget {
  const CheckoutReceiptScreen({super.key, required this.checkoutId});
  final String checkoutId;
  @override
  State<CheckoutReceiptScreen> createState() => _CheckoutReceiptScreenState();
}

class _CheckoutReceiptScreenState extends State<CheckoutReceiptScreen> {
  late final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _receipt = FirebaseFirestore.instance
      .doc('users/$_uid/receipts/${widget.checkoutId}')
      .snapshots();
  late final _orders = FirebaseFirestore.instance
      .collection('orders')
      .where('customerId', isEqualTo: _uid)
      .where('checkoutGroupId', isEqualTo: widget.checkoutId)
      .limit(20)
      .snapshots();
  String _money(num sen) => 'RM ${(sen / 100).toStringAsFixed(2)}';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Checkout receipt')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _receipt,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Could not load your receipt. Reopen this screen to retry.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final receipt = snapshot.data!.data();
        if (receipt == null) {
          return const Center(
            child: Text(
              'A combined receipt is unavailable for this older checkout.',
            ),
          );
        }
        final groups = (receipt['groups'] as List).cast<Map>();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Bloom & Bunch KL',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('Checkout ${widget.checkoutId}'),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _orders,
              builder: (context, orders) {
                if (orders.hasError) {
                  return const Text('Payment status could not be loaded.');
                }
                if (!orders.hasData) return const LinearProgressIndicator();
                final statuses = orders.data!.docs
                    .map((o) => o.data()['paymentStatus'])
                    .toSet();
                return Text(
                  receipt['orderMode'] == 'demo'
                      ? 'Demonstration order · no payment collected'
                      : statuses.length == 1 && statuses.contains('paid')
                      ? 'Payment confirmed'
                      : statuses.contains('expired')
                      ? 'Payment expired'
                      : 'Payment awaiting confirmation',
                );
              },
            ),
            for (final group in groups) ...[
              const Divider(height: 32),
              Text(
                'Delivery · ${group['date']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final raw in group['items'] as List)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${raw['quantity']} × ${raw['name']}'),
                  subtitle: raw['type'] == 'addon'
                      ? const Text('Add-on')
                      : null,
                  trailing: Text(
                    'RM ${((raw['unitPrice'] as num) * (raw['quantity'] as num)).toStringAsFixed(2)}',
                  ),
                ),
              if (group['messageCard'] is Map) ...[
                Text('Message card · ${_money(group['cardFeeSen'] as num)}'),
                MessageCardPreview(
                  designName: group['messageCard']['designName'] as String,
                  imageUrl: group['messageCard']['imageUrl'] as String? ?? '',
                  message: group['messageCard']['message'] as String,
                  senderName: group['messageCard']['senderName'] as String,
                ),
              ],
            ],
            const Divider(height: 32),
            Text('Items: ${_money(receipt['subtotalSen'] as num)}'),
            Text('Message cards: ${_money(receipt['cardFeeSen'] as num)}'),
            Text(
              'Total: ${_money(receipt['totalSen'] as num)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'One combined payment covers all listed items and deliveries.',
            ),
          ],
        );
      },
    ),
  );
}
