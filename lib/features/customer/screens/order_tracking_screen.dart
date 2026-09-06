import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';

const _friendlyStatus = {
  'Pending': 'Received',
  'Processing': 'Assembling',
  'Ready for Delivery': 'Out for Delivery',
  'Completed': 'Delivered',
};

const _statusSteps = ['Received', 'Assembling', 'Out for Delivery', 'Delivered'];

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Order')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data()!;
          final rawStatus = data['orderStatus'] ?? 'Pending';
          final friendly = _friendlyStatus[rawStatus] ?? rawStatus;
          final currentStepIndex = _statusSteps.indexOf(friendly).clamp(0, _statusSteps.length - 1);
          final address = data['deliveryAddress'] ?? '';
          final hasRider = data['riderId'] != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 20),
                        Row(
                          children: List.generate(_statusSteps.length, (i) {
                            final isDone = i <= currentStepIndex;
                            return Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      if (i > 0)
                                        Expanded(
                                          child: Container(height: 3, color: isDone ? AppColors.primaryRosewood : AppColors.inputBorder),
                                        ),
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDone ? AppColors.primaryRosewood : AppColors.inputBorder,
                                        ),
                                        child: isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                      ),
                                      if (i < _statusSteps.length - 1)
                                        Expanded(
                                          child: Container(height: 3, color: i < currentStepIndex ? AppColors.primaryRosewood : AppColors.inputBorder),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _statusSteps[i],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                                      color: isDone ? AppColors.textDark : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: AppColors.primaryRosewood),
                    title: const Text('Delivering to'),
                    subtitle: Text(address),
                  ),
                ),
                const SizedBox(height: 16),
                if (!hasRider)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.softBlushStart, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primaryRosewood, size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text('Live rider location will appear here once a rider is assigned to your order.', style: TextStyle(fontSize: 13))),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.softBlushStart, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.pedal_bike, color: AppColors.primaryRosewood, size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text('A rider has been assigned to your order.', style: TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}