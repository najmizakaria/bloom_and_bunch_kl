import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Track order')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, s) {
        if (s.hasError) {
          return const Center(
            child: Text('Unable to load this order. Please try again.'),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (!s.data!.exists) {
          return const Center(child: Text('Order not found.'));
        }
        final d = s.data!.data()!, raw = d['orderStatus'] ?? 'Pending';
        final status = raw == 'Pending'
            ? 'Awaiting Preparation'
            : raw == 'Completed'
            ? 'Delivered'
            : raw;
        final ready = d['fulfillmentType'] == 'ready_now';
        final stages = ready
            ? ['Ready for Delivery', 'Out for Delivery', 'Delivered']
            : [
                'Awaiting Preparation',
                'Processing',
                'Ready for Delivery',
                'Out for Delivery',
                'Delivered',
              ];
        final index = stages.indexOf(status);
        final labels = {
          'Awaiting Preparation': 'Order confirmed',
          'Processing': 'Preparing bouquet',
          'Ready for Delivery': 'Ready for rider collection',
          'Out for Delivery': 'Out for delivery',
          'Delivered': 'Delivered',
        };
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Order #${orderId.substring(0, 8).toUpperCase()}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (status == 'Cancelled')
              const ListTile(
                leading: Icon(Icons.cancel),
                title: Text('Order cancelled'),
              )
            else
              ...List.generate(
                stages.length,
                (i) => ListTile(
                  leading: Icon(
                    i <= index
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(labels[stages[i]]!),
                  subtitle: i == index ? const Text('Current status') : null,
                ),
              ),
            Card(
              child: ListTile(
                title: const Text('Delivering to'),
                subtitle: Text(
                  '${d['recipientName'] ?? ''}\n${d['deliveryAddress'] ?? ''}',
                ),
              ),
            ),
            ListTile(
              title: const Text('Delivery timing'),
              subtitle: Text(d['deliveryTimeSlot'] ?? ''),
            ),
            Text(
              d['riderId'] == null
                  ? 'Waiting for rider assignment after the bouquet is ready.'
                  : 'A rider has accepted your delivery.',
            ),
          ],
        );
      },
    ),
  );
}
