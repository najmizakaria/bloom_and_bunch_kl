import 'package:flutter/material.dart';
import '../../../models/flower_model.dart';

class FlowerDetailScreen extends StatelessWidget {
  final FlowerModel flower;

  const FlowerDetailScreen({super.key, required this.flower});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(flower.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flower Image Display
                  Container(
                    height: 250,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: flower.imageUrl.isNotEmpty
                        ? Image.network(flower.imageUrl, fit: BoxFit.cover)
                        : const Icon(Icons.local_florist, size: 100, color: Colors.grey),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flower.name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Category: ${flower.category}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'RM ${flower.pricePerStem.toStringAsFixed(2)} / stem',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD87093),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              flower.isAvailable ? Icons.check_circle : Icons.cancel,
                              color: flower.isAvailable ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              flower.isAvailable
                                  ? 'In Stock (${flower.stockQuantity} stems available)'
                                  : 'Out of Stock',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD87093),
                  foregroundColor: Colors.white,
                ),
                onPressed: flower.isAvailable
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Proceed to Sprint 3: Custom Bouquet Builder! ⭐'),
                          ),
                        );
                      }
                    : null,
                child: const Text('Use in Custom Bouquet', style: TextStyle(fontSize: 16)),
              ),
            ),
          )
        ],
      ),
    );
  }
}