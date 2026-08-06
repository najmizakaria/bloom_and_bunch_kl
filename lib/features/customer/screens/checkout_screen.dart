import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_home_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final double totalPrice;
  final Map<String, int> stemCounts;
  final String wrapper;
  final String ribbon;
  final String cardNote;

  const CheckoutScreen({
    super.key,
    required this.totalPrice,
    required this.stemCounts,
    required this.wrapper,
    required this.ribbon,
    required this.cardNote,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _placeOrder() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all delivery details.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Filter out stems with 0 count to save space in the database
      final validStems = widget.stemCounts.entries
          .where((entry) => entry.value > 0)
          .map((entry) => {'flowerId': entry.key, 'quantity': entry.value})
          .toList();

      // Create the Order Document in Firestore
      await FirebaseFirestore.instance.collection('orders').add({
        'customerId': user?.uid ?? 'unknown',
        'recipientName': _nameController.text.trim(),
        'deliveryAddress': _addressController.text.trim(),
        'recipientPhone': _phoneController.text.trim(),
        'totalAmount': widget.totalPrice,
        'orderStatus': 'Pending',
        'deliveryDate': Timestamp.now(),
        'deliveryTimeSlot': '10:00 AM - 2:00 PM',
        'bouquetDetails': {
          'stems': validStems,
          'wrapper': widget.wrapper,
          'ribbon': widget.ribbon,
          'cardNote': widget.cardNote,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Show success message and return to Home Screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order Placed Successfully! 🎉'), backgroundColor: Colors.green),
      );
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing order: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Text('Wrapper: ${widget.wrapper}'),
                    const SizedBox(height: 4),
                    Text('Ribbon: ${widget.ribbon}'),
                    const SizedBox(height: 4),
                    Text('Note: ${widget.cardNote.isEmpty ? "None" : widget.cardNote}'),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          'RM ${widget.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD87093)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Delivery Details Form
            const Text('Delivery Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Recipient Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Recipient Phone', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Full Delivery Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),

            // Place Order Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD87093),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isProcessing ? null : _placeOrder,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Place Order', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}