import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/favourites_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/flower_model.dart';

class BouquetBuilderScreen extends StatefulWidget {
  const BouquetBuilderScreen({super.key});

  @override
  State<BouquetBuilderScreen> createState() => _BouquetBuilderScreenState();
}

class _BouquetBuilderScreenState extends State<BouquetBuilderScreen> {
  final Map<String, int> _stemCounts = {};
  final FavouritesService _favouritesService = FavouritesService();

  String _selectedWrapper = 'Kraft Paper (Classic)';
  double _wrapperPrice = 5.00;

  String _selectedRibbon = 'Red Satin';
  double _ribbonPrice = 2.00;

  final TextEditingController _cardNoteController = TextEditingController();

  final Map<String, double> _wrapperOptions = {
    'Kraft Paper (Classic)': 5.00,
    'Pastel Pink Waterproof': 8.00,
    'Minimalist Matte Black': 8.00,
    'Satin White Luxury': 10.00,
  };

  final Map<String, double> _ribbonOptions = {
    'Red Satin': 2.00,
    'Gold Silk': 3.50,
    'Rose Gold Organza': 3.50,
    'Minimalist Twine': 1.50,
  };

  double _calculateTotalPrice(List<FlowerModel> availableFlowers) {
    double stemsTotal = 0.0;
    for (var flower in availableFlowers) {
      final count = _stemCounts[flower.flowerId] ?? 0;
      stemsTotal += (flower.pricePerStem * count);
    }
    return stemsTotal + _wrapperPrice + _ribbonPrice;
  }

  bool get _hasStems => _stemCounts.values.any((stemCount) => stemCount > 0);

  Future<void> _saveRecipe(double totalPrice) async {
    if (!_hasStems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one stem before saving.')),
      );
      return;
    }
    await _favouritesService.saveRecipe(
      stems: _stemCounts,
      wrapper: _selectedWrapper,
      ribbon: _selectedRibbon,
      totalPrice: totalPrice,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe saved to Favourites ♡'), backgroundColor: Colors.green),
    );
  }

void _addToCart(
  double totalPrice,
  List<FlowerModel> availableFlowers,
) {
  if (!_hasStems) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Add at least one stem before adding to cart.',
        ),
      ),
    );
    return;
  }

  final flowersById = {
    for (final flower in availableFlowers)
      flower.flowerId: flower,
  };

  for (final entry in _stemCounts.entries) {
    if (entry.value <= 0) continue;

    final flower = flowersById[entry.key];

    if (flower == null || !flower.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'One selected flower is no longer available. Please update your bouquet.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (entry.value > flower.stockQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only ${flower.stockQuantity} ${flower.name} stems are available.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
  }

  final selectedStems = Map<String, int>.fromEntries(
    _stemCounts.entries.where(
      (entry) => entry.value > 0,
    ),
  );

  context.read<CartProvider>().addCustomItem(
        unitPrice: totalPrice,
        stems: selectedStems,
        wrapper: _selectedWrapper,
        ribbon: _selectedRibbon,
        cardNote: _cardNoteController.text.trim(),
      );

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Added to cart 🛒'),
      backgroundColor: Colors.green,
    ),
  );

  setState(() {
    _stemCounts.clear();
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Bouquet Builder 💐')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('flowers').where('isAvailable', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No flower stems available right now.'));
          }

          final flowers = snapshot.data!.docs
              .map(
                (document) => FlowerModel.fromMap(
                  document.data() as Map<String, dynamic>,
                  document.id,
                ),
              )
              .where(
                (flower) =>
                    flower.isAvailable &&
                    flower.stockQuantity > 0,
              )
              .toList();
          
          if (flowers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No flower stems are available right now.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final totalPrice = _calculateTotalPrice(flowers);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Operational Notice
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.softBlushStart,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryRosewood.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.access_time, color: AppColors.primaryRosewood),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Custom bouquets take 1–2 hours to assemble by our florist.',
                                style: TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text('1. Choose Flower Stems', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: flowers.length,
                        itemBuilder: (context, index) {
                          final flower = flowers[index];
                          final count = _stemCounts[flower.flowerId] ?? 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            child: ListTile(
                              leading: flower.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(flower.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                                    )
                                  : const Icon(Icons.local_florist, size: 40, color: AppColors.primaryRosewood),
                              title: Text(flower.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('RM ${flower.pricePerStem.toStringAsFixed(2)} / stem'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: count > 0
                                        ? () => setState(() => _stemCounts[flower.flowerId] = count - 1)
                                        : null,
                                  ),
                                  Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                    onPressed: count < flower.stockQuantity
                                        ? () => setState(() => _stemCounts[flower.flowerId] = count + 1)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text('2. Choose Wrapping Paper', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedWrapper,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _wrapperOptions.entries
                            .map((entry) => DropdownMenuItem(value: entry.key, child: Text('${entry.key} (+RM ${entry.value.toStringAsFixed(2)})')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedWrapper = val;
                              _wrapperPrice = _wrapperOptions[val]!;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text('3. Choose Ribbon Style', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRibbon,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _ribbonOptions.entries
                            .map((entry) => DropdownMenuItem(value: entry.key, child: Text('${entry.key} (+RM ${entry.value.toStringAsFixed(2)})')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedRibbon = val;
                              _ribbonPrice = _ribbonOptions[val]!;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text('4. Gift Message Card', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _cardNoteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Write your personalized message here...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom Actions Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -4))],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Price', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          Text(
                            'RM ${totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryRosewood),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryRosewood,
                                side: const BorderSide(color: AppColors.primaryRosewood),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.favorite_border),
                              label: const Text('Save Recipe'),
                              onPressed: () => _saveRecipe(totalPrice),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRosewood,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.shopping_cart_outlined),
                              label: const Text('Add to Cart'),
                              onPressed: () {
                                _addToCart(
                                  totalPrice,
                                  flowers,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}