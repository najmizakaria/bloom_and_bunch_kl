import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/order_model.dart';

class RiderOrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const RiderOrderDetailScreen({super.key, required this.order});

  @override
  State<RiderOrderDetailScreen> createState() => _RiderOrderDetailScreenState();
}

class _RiderOrderDetailScreenState extends State<RiderOrderDetailScreen> {
  bool _isLoading = false;

  Future<void> _acceptDelivery() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      await FirebaseFirestore.instance.collection('orders').doc(widget.order.orderId).update({
        'riderId': currentUserId,
        'orderStatus': 'Out for Delivery',
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery Accepted! Drive safe! 🛵'), backgroundColor: Colors.green),
      );
      Navigator.pop(context); // Go back to dashboard
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsDelivered() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.order.orderId).update({
        'orderStatus': 'Delivered',
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Awesome job! Order Delivered. 🎉'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which button to show based on status
    final isAvailable = widget.order.orderStatus == 'Ready for Delivery';
    final isOutForDelivery = widget.order.orderStatus == 'Out for Delivery';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Route'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: isAvailable ? Colors.orange.shade50 : Colors.blue.shade50,
              child: ListTile(
                title: const Text('Current Status', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(widget.order.orderStatus, style: TextStyle(color: isAvailable ? Colors.orange : Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),

            // Delivery Information
            const Text('Drop-off Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person, color: Colors.deepOrange),
              title: Text(widget.order.recipientName),
              subtitle: const Text('Recipient'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone, color: Colors.deepOrange),
              title: Text(widget.order.recipientPhone),
              subtitle: const Text('Phone Number'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on, color: Colors.deepOrange),
              title: Text(widget.order.deliveryAddress),
              subtitle: const Text('Full Address'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time, color: Colors.deepOrange),
              title: Text(widget.order.deliveryTimeSlot),
              subtitle: const Text('Requested Time Slot'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAvailable ? Colors.deepOrange : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: isAvailable 
                    ? _acceptDelivery 
                    : (isOutForDelivery ? _markAsDelivered : null),
                child: Text(
                  isAvailable ? 'Accept Delivery' : 'Mark as Delivered',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }
}