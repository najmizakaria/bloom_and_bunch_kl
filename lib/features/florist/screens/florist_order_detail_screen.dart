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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bouquet = widget.order.bouquetDetails;
    final List<dynamic> stems = bouquet['stems'] ?? [];

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
            const SizedBox(height: 20),

            // Bouquet Recipe
            const Text('Bouquet Recipe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            const Text('Stems to include:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ...stems.map((stem) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• ${stem['quantity']}x ${stem['flowerId']}'),
                )),
            const SizedBox(height: 12),
            Text('Wrapper: ${bouquet['wrapper']}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text('Ribbon: ${bouquet['ribbon']}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            
            // Note Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer Note Card:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 8),
                  Text(bouquet['cardNote']?.isEmpty ?? true ? 'No note provided' : bouquet['cardNote'],
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
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
          ],
        ),
      ),
    );
  }
}