import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import '../../../models/flower_model.dart';
import 'bouquet_builder_screen.dart';

class FlowerDetailScreen extends StatelessWidget {
  final FlowerModel flower;

  const FlowerDetailScreen({super.key, required this.flower});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
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
                        : const Icon(
                            Icons.local_florist,
                            size: 100,
                            color: Colors.grey,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flower.name,
                          style: const AppTypography.screenTitle(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Category: ${flower.category}',
                          style: AppTypography.body(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'RM ${flower.pricePerStem.toStringAsFixed(2)} / stem',
                          style: const AppTypography.total(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              flower.availableForCustomOrder
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: flower.availableForCustomOrder
                                  ? AppColors.primaryDark
                                  : AppColors.primaryDark,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              flower.availableForCustomOrder
                                  ? 'Choose a delivery date after preparation'
                                  : 'Currently not offered',
                              style: const AppTypography.body(),
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BouquetBuilderScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Use in Custom Bouquet',
                  style: AppTypography.button(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
