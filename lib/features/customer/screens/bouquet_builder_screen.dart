import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  static const int _maximumPerFlower = 100;
  static const int _maximumTotalStems = 150;

  final Map<String, int> _stemCounts = {};
  final FavouritesService _favouritesService = FavouritesService();
  final TextEditingController _cardNoteController = TextEditingController();

  String _selectedWrapper = 'Kraft Paper (Classic)';
  double _wrapperPrice = 5;
  String _selectedRibbon = 'Red Satin';
  double _ribbonPrice = 2;

  final Map<String, double> _wrapperOptions = {
    'Kraft Paper (Classic)': 5,
    'Pastel Pink Waterproof': 8,
    'Minimalist Matte Black': 8,
    'Satin White Luxury': 10,
  };

  final Map<String, double> _ribbonOptions = {
    'Red Satin': 2,
    'Gold Silk': 3.50,
    'Rose Gold Organza': 3.50,
    'Minimalist Twine': 1.50,
  };

  int get _totalSelectedStems =>
      _stemCounts.values.fold(0, (total, quantity) => total + quantity);

  Map<String, int> _selectedStemsFor(List<FlowerModel> flowers) {
    final sourceableIds = flowers.map((flower) => flower.flowerId).toSet();
    return Map<String, int>.fromEntries(
      _stemCounts.entries.where(
        (entry) => sourceableIds.contains(entry.key) && entry.value > 0,
      ),
    );
  }

  double _calculateTotalPrice(List<FlowerModel> flowers) {
    double stemsTotal = 0;
    for (final flower in flowers) {
      final count = _stemCounts[flower.flowerId] ?? 0;
      stemsTotal += flower.pricePerStem * count;
    }
    return stemsTotal + _wrapperPrice + _ribbonPrice;
  }

  void _decrementFlower(FlowerModel flower) {
    final current = _stemCounts[flower.flowerId] ?? 0;
    if (current <= 0) return;

    setState(() {
      if (current == 1) {
        _stemCounts.remove(flower.flowerId);
      } else {
        _stemCounts[flower.flowerId] = current - 1;
      }
    });
  }

  void _incrementFlower(FlowerModel flower) {
    final current = _stemCounts[flower.flowerId] ?? 0;
    if (current >= _maximumPerFlower ||
        _totalSelectedStems >= _maximumTotalStems) {
      _showQuantityLimit();
      return;
    }

    setState(() {
      _stemCounts[flower.flowerId] = current + 1;
    });
  }

  void _showQuantityLimit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'You can select up to 100 stems per flower and 150 stems per bouquet.',
        ),
      ),
    );
  }

  Future<void> _enterExactQuantity(FlowerModel flower) async {
    final current = _stemCounts[flower.flowerId] ?? 0;
    final stemsFromOtherFlowers = _totalSelectedStems - current;
    final maximumAllowed = min(
      _maximumPerFlower,
      _maximumTotalStems - stemsFromOtherFlowers,
    );
    var entered = '$current';
    final formKey = GlobalKey<FormState>();

    final selectedQuantity = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${flower.name} quantity'),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: entered,
              onChanged: (value) => entered = value,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of stems',
                helperText: 'Enter 0 to $maximumAllowed stems',
              ),
              validator: (value) {
                final quantity = int.tryParse(value?.trim() ?? '');
                if (quantity == null) return 'Enter a whole number.';
                if (quantity < 0 || quantity > maximumAllowed) {
                  return 'Enter a number from 0 to $maximumAllowed.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext, int.parse(entered.trim()));
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (!mounted || selectedQuantity == null) return;

    setState(() {
      if (selectedQuantity == 0) {
        _stemCounts.remove(flower.flowerId);
      } else {
        _stemCounts[flower.flowerId] = selectedQuantity;
      }
    });
  }

  Future<void> _saveRecipe(double totalPrice, List<FlowerModel> flowers) async {
    final selectedStems = _selectedStemsFor(flowers);
    if (selectedStems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one stem before saving.')),
      );
      return;
    }

    try {
    await _favouritesService.saveRecipe(
      stems: selectedStems,
      wrapper: _selectedWrapper,
      ribbon: _selectedRibbon,
      totalPrice: totalPrice,
    );
    } catch (_) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Unable to save recipe. Please retry.')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recipe saved to Favourites'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _addToCart(double totalPrice, List<FlowerModel> flowers) {
    final selectedStems = _selectedStemsFor(flowers);
    if (selectedStems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one stem before adding to cart.'),
        ),
      );
      return;
    }

    final selectedNames = <String, String>{
      for (final flower in flowers)
        if (selectedStems.containsKey(flower.flowerId))
          flower.flowerId: flower.name,
    };

    context.read<CartProvider>().addCustomItem(
      unitPrice: totalPrice,
      stems: selectedStems,
      stemNames: selectedNames,
      wrapper: _selectedWrapper,
      ribbon: _selectedRibbon,
      cardNote: _cardNoteController.text.trim(),
      leadTimeBusinessDays: 2,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom bouquet added to cart'),
        backgroundColor: Colors.green,
      ),
    );

    setState(_stemCounts.clear);
  }

  @override
  void dispose() {
    _cardNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Bouquet Builder')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('flowers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'We could not load the flower choices. Please try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final flowers =
              (snapshot.data?.docs ?? [])
                  .map(
                    (document) =>
                        FlowerModel.fromMap(document.data(), document.id),
                  )
                  .where((flower) => flower.availableForCustomOrder)
                  .toList()
                ..sort(
                  (first, second) => first.name.toLowerCase().compareTo(
                    second.name.toLowerCase(),
                  ),
                );

          if (flowers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No flowers are offered for custom bouquets right now.',
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPlanningNotice(),
                      const SizedBox(height: 20),
                      const Text(
                        '1. Choose Flower Stems',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Most bouquets use 12–24 stems. Choose any amount '
                        'that suits your design.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: flowers.length,
                        itemBuilder: (context, index) {
                          return _buildFlowerCard(flowers[index]);
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildWrapperField(),
                      const SizedBox(height: 20),
                      _buildRibbonField(),
                      const SizedBox(height: 20),
                      const Text(
                        '4. Gift Message Card',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _cardNoteController,
                        maxLines: 3,
                        maxLength: 250,
                        decoration: InputDecoration(
                          hintText: 'Write your personalized message here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(totalPrice, flowers),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlanningNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softBlushStart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryRosewood.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calendar_month, color: AppColors.primaryRosewood),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Custom bouquets are prepared in 1–3 business days. '
              'The florist will source the flowers needed for your design.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowerCard(FlowerModel flower) {
    final count = _stemCounts[flower.flowerId] ?? 0;
    final canAdd =
        count < _maximumPerFlower && _totalSelectedStems < _maximumTotalStems;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: flower.imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  flower.imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(
                        Icons.local_florist,
                        color: AppColors.primaryRosewood,
                      ),
                    );
                  },
                ),
              )
            : const SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  Icons.local_florist,
                  size: 36,
                  color: AppColors.primaryRosewood,
                ),
              ),
        title: Text(
          flower.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('RM ${flower.pricePerStem.toStringAsFixed(2)} / stem'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Remove one stem',
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: count > 0 ? () => _decrementFlower(flower) : null,
            ),
            TextButton(
              onPressed: () => _enterExactQuantity(flower),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Add one stem',
              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
              onPressed: canAdd ? () => _incrementFlower(flower) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrapperField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. Choose Wrapping Paper',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _selectedWrapper,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          items: _wrapperOptions.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(
                    '${entry.key} (+RM ${entry.value.toStringAsFixed(2)})',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedWrapper = value;
              _wrapperPrice = _wrapperOptions[value]!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRibbonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. Choose Ribbon Style',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _selectedRibbon,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          items: _ribbonOptions.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(
                    '${entry.key} (+RM ${entry.value.toStringAsFixed(2)})',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedRibbon = value;
              _ribbonPrice = _ribbonOptions[value]!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar(double totalPrice, List<FlowerModel> flowers) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_totalSelectedStems stems',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'RM ${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRosewood,
                  ),
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
                    onPressed: () => _saveRecipe(totalPrice, flowers),
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
                    onPressed: () => _addToCart(totalPrice, flowers),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
