import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/flower_model.dart';

class FloristInventoryScreen extends StatelessWidget {
  const FloristInventoryScreen({super.key});

  // Helper to instantly update stock quantity
  Future<void> _updateStock(String docId, int currentStock, int change) async {
    int newStock = currentStock + change;
    if (newStock < 0) newStock = 0; // Prevent negative stock
    await FirebaseFirestore.instance.collection('flowers').doc(docId).update({
      'stockQuantity': newStock,
    });
  }

  // Helper to toggle availability (hide/show from customers)
  Future<void> _toggleAvailability(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('flowers').doc(docId).update({
      'isAvailable': !currentStatus,
    });
  }

  // Dialog to Add a Brand New Flower
  void _showAddFlowerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Flower 🌸'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Flower Name (e.g. Red Rose)')),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category (e.g. Roses, Lilies)')),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price per stem (RM)'), keyboardType: TextInputType.number),
              TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Initial Stock Quantity'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty || stockCtrl.text.isEmpty) return;
              
              await FirebaseFirestore.instance.collection('flowers').add({
                'name': nameCtrl.text.trim(),
                'category': categoryCtrl.text.trim(),
                'pricePerStem': double.tryParse(priceCtrl.text) ?? 0.0,
                'stockQuantity': int.tryParse(stockCtrl.text) ?? 0,
                'imageUrl': '', // You can add image uploading later!
                'isAvailable': true,
              });
              
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add to Stock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Inventory 📦'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFlowerDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Flower'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('flowers').orderBy('category').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No flowers in stock yet! Add some below.'));
          }

          final flowers = snapshot.data!.docs.map((doc) {
            return FlowerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, top: 12),
            itemCount: flowers.length,
            itemBuilder: (context, index) {
              final flower = flowers[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // Flower Info
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(flower.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${flower.category} • RM ${flower.pricePerStem.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Available: ', style: TextStyle(fontSize: 12)),
                                Switch(
                                  value: flower.isAvailable,
                                  onChanged: (val) => _toggleAvailability(flower.flowerId, flower.isAvailable),
                                  activeColor: Colors.teal,
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      
                      // Stock Controls
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            const Text('Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => _updateStock(flower.flowerId, flower.stockQuantity, -1),
                                ),
                                Text('${flower.stockQuantity}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: () => _updateStock(flower.flowerId, flower.stockQuantity, 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}