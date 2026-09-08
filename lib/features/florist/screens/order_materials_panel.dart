import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/order_model.dart';

class OrderMaterialsPanel extends StatelessWidget {
  final OrderModel order;
  const OrderMaterialsPanel({super.key, required this.order});
  @override
  Widget build(BuildContext context) {
    final requiredStems = <String, int>{};
    for (final item in order.items) {
      final stems = item['recipeStems'] ?? item['customStems'];
      if (stems is! Map) continue;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      for (final e in stems.entries) {
        requiredStems.update(
          e.key.toString(),
          (v) => v + (e.value as num).toInt() * quantity,
          ifAbsent: () => (e.value as num).toInt() * quantity,
        );
      }
    }
    if (requiredStems.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('flowers').snapshots(),
      builder: (context, s) {
        if (s.hasError) return const Text('Unable to load material stock.');
        if (!s.hasData) return const LinearProgressIndicator();
        final flowers = {for (final d in s.data!.docs) d.id: d.data()};
        return Card(
          child: Column(
            children: [
              const ListTile(
                title: Text('Materials for this order'),
                subtitle: Text('Reservations include all open planned orders.'),
              ),
              ...requiredStems.entries.map((e) {
                final f = flowers[e.key],
                    stock = (f?['stockQuantity'] as num?)?.toInt() ?? 0,
                    reserved = (f?['reservedQuantity'] as num?)?.toInt() ?? 0;
                final shortage = (reserved - stock).clamp(0, 999999);
                return ListTile(
                  title: Text(f?['name'] ?? 'Removed flower'),
                  subtitle: Text(
                    'This order: ${e.value} · On hand: $stock · All reserved: $reserved',
                  ),
                  trailing: Text(
                    shortage > 0 ? 'Restock $shortage' : 'Covered',
                    style: TextStyle(
                      color: shortage > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
