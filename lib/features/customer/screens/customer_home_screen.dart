import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/favourites_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bouquet_model.dart';
import 'bouquet_builder_screen.dart';

enum DeliveryMode { readyNow, preOrder }

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final List<String> categories = ['All', 'Birthday', 'Anniversary', 'Sympathy', 'Romance'];
  String selectedCategory = 'All';
  DeliveryMode deliveryMode = DeliveryMode.readyNow;

  String _address = 'Detecting location...';
  bool _locatingGPS = true;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    setState(() => _locatingGPS = true);
    try {
      final address = await LocationService().getCurrentAddress();
      if (mounted) setState(() => _address = address);
    } catch (e) {
      if (mounted) setState(() => _address = 'Set delivery address');
    } finally {
      if (mounted) setState(() => _locatingGPS = false);
    }
  }

  void _openAddressSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter address, e.g. Jalan Song, Kuching',
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryRosewood,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    setState(() => _address = controller.text.trim());
                  }
                  Navigator.pop(context);
                },
                child: const Text('Confirm Address'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Use current GPS location'),
              onPressed: () {
                Navigator.pop(context);
                _detectLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: GestureDetector(
          onTap: _openAddressSheet,
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primaryRosewood, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: _locatingGPS
                    ? const Text('Detecting location...', style: TextStyle(fontSize: 14, color: AppColors.textMuted))
                    : Text(
                        _address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery Mode Switcher
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(child: _modeButton('⚡ Ready-to-Send', DeliveryMode.readyNow)),
                  Expanded(child: _modeButton('📅 Pre-Order', DeliveryMode.preOrder)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Express Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.softBlushStart, AppColors.softBlushEnd],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'In a Rush? 🌸',
                    style: TextStyle(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pick a Ready-Made Bouquet for instant dispatch.',
                    style: TextStyle(color: AppColors.textDark, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Custom bouquet entry point
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BouquetBuilderScreen()),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryRosewood,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Want something custom? Build your own bouquet.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: AppColors.primaryRosewood,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textDark),
                      onSelected: (selected) => setState(() => selectedCategory = cat),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            const Text('Ready-Made Bouquets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Bouquets feed — ready-made ONLY, individual stems never shown here
            StreamBuilder<QuerySnapshot>(
              stream: (selectedCategory == 'All'
                      ? FirebaseFirestore.instance.collection('bouquets')
                      : FirebaseFirestore.instance
                          .collection('bouquets')
                          .where('category', isEqualTo: selectedCategory))
                  .where('readyToSend', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No ready-made bouquets in this category yet.')),
                  );
                }

                final docs = snapshot.data!.docs;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final bouquet = BouquetModel.fromMap(
                      docs[index].data() as Map<String, dynamic>,
                      docs[index].id,
                    );

return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                bouquet.imageUrl.isNotEmpty
                                    ? Image.network(
                                        bouquet.imageUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.local_florist, size: 50),
                                      )
                                    : const Icon(Icons.local_florist, size: 50),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                    stream: FavouritesService().isBouquetFavourited(bouquet.id),
                                    builder: (context, favSnapshot) {
                                      final isFavourited = favSnapshot.data?.exists ?? false;
                                      return GestureDetector(
                                        onTap: () => FavouritesService().toggleBouquetFavourite(
                                          bouquetId: bouquet.id,
                                          name: bouquet.name,
                                          imageUrl: bouquet.imageUrl,
                                          price: bouquet.price,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
                                          child: Icon(
                                            isFavourited ? Icons.favorite : Icons.favorite_border,
                                            size: 16,
                                            color: AppColors.primaryRosewood,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bouquet.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'RM ${bouquet.price.toStringAsFixed(2)}',
                                      style: const TextStyle(color: AppColors.primaryRosewood, fontWeight: FontWeight.bold),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        context.read<CartProvider>().addReadyMadeItem(
                                              bouquetId: bouquet.id,
                                              name: bouquet.name,
                                              imageUrl: bouquet.imageUrl,
                                              price: bouquet.price,
                                            );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('${bouquet.name} added to cart'), duration: const Duration(seconds: 1)),
                                        );
                                      },
                                      child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: AppColors.primaryRosewood,
                                        child: Icon(Icons.add, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(String label, DeliveryMode mode) {
    final isSelected = deliveryMode == mode;
    return GestureDetector(
      onTap: () => setState(() => deliveryMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.primaryRosewood : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}