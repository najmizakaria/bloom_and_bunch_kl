import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/order_model.dart';

class FloristOrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const FloristOrderDetailScreen({super.key, required this.order});

  @override
  State<FloristOrderDetailScreen> createState() => _FloristOrderDetailScreenState();
}

class _FloristOrderDetailScreenState extends State<FloristOrderDetailScreen> {
  late String _currentStatus;
  final List<String> _statusOptions = ['Pending', 'Processing', 'Ready for Delivery', 'Completed'];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.orderStatus;
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.order.orderId).update({
        'orderStatus': newStatus,
      });
      setState(() => _currentStatus = newStatus);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Updater Card
            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Order Status:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _statusOptions.contains(_currentStatus) ? _currentStatus : 'Pending',
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem(value: status, child: Text(status));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _currentStatus) {
                          _updateStatus(val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Prep-time flag, since custom items need florist assembly time
            if (widget.order.requiresPrepTime)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This order contains custom bouquet(s) — allow 1–2 hours prep time before dispatch.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Order Items
            Text('Order Items (${items.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),

            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No items found on this order.', style: TextStyle(color: Colors.grey)),
              ),

            ...items.map((item) {
              final isCustom = item['type'] == 'custom';
              final quantity = item['quantity'] ?? 1;
              final unitPrice = (item['unitPrice'] ?? 0).toDouble();
              final stems = (item['customStems'] as Map<String, dynamic>? ?? {});
              final cardNote = (item['cardNote'] ?? '').toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item['name'] ?? 'Item'} x$quantity',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCustom ? Colors.purple.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isCustom ? 'Custom' : 'Ready-made',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCustom ? Colors.purple : Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('RM ${unitPrice.toStringAsFixed(2)} each', style: const TextStyle(color: Colors.grey, fontSize: 13)),

                      if (isCustom) ...[
                        const SizedBox(height: 10),
                        const Text('Stems to include:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 4),
                        if (stems.isEmpty)
                          const Text('No stems recorded.', style: TextStyle(color: Colors.grey))
                        else
                          ...stems.entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('• ${e.value}x ${e.key}'),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text('Wrapper: ${item['wrapper'] ?? '-'}', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('Ribbon: ${item['ribbon'] ?? '-'}', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Customer Note Card:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                cardNote.isEmpty ? 'No note provided' : cardNote,
                                style: const TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Order Total: RM ${widget.order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 24),

            // Delivery Details
            const Text('Delivery Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Text('Recipient: ${widget.order.recipientName}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text('Phone: ${widget.order.recipientPhone}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text('Address: ${widget.order.deliveryAddress}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text('Delivery Slot: ${widget.order.deliveryTimeSlot}', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}