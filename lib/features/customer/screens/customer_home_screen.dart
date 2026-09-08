import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/fulfillment_constants.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/address_service.dart';
import '../../../core/services/favourites_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bouquet_model.dart';
import '../../../models/saved_address_model.dart';
import 'address_book_screen.dart';
import 'bouquet_builder_screen.dart';

enum DeliveryMode { readyNow, preOrder }

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const List<String> _categories = [
    'All',
    'Birthday',
    'Anniversary',
    'Sympathy',
    'Romance',
  ];

  String _selectedCategory = 'All';
  DeliveryMode _deliveryMode = DeliveryMode.readyNow;
  String _address = 'Set delivery address';
  bool _locatingGps = true;

  String get _fulfillmentType => _deliveryMode == DeliveryMode.readyNow
      ? FulfillmentTypes.readyNow
      : FulfillmentTypes.preOrder;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final address = await AddressService().defaultAddress();
      if (mounted && address != null) {
        setState(() => _address = address.address);
      }
    } catch (_) {
      if (mounted) setState(() => _address = 'Set delivery address');
    } finally {
      if (mounted) setState(() => _locatingGps = false);
    }
  }

  Future<void> _openAddressSheet() async {
    final address = await Navigator.push<SavedAddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddressBookScreen(selectionMode: true),
      ),
    );
    if (mounted && address != null) {
      setState(() => _address = address.address);
    }
  }

  bool _belongsInSelectedMode(BouquetModel bouquet) {
    if (!bouquet.isPublished) return false;

    if (_selectedCategory != 'All' && bouquet.category != _selectedCategory) {
      return false;
    }

    if (_deliveryMode == DeliveryMode.readyNow) {
      return bouquet.availableForReadyNow && bouquet.readyStock > 0;
    }

    return bouquet.availableForPreOrder;
  }

  void _addBouquetToCart(BouquetModel bouquet) {
    context.read<CartProvider>().addReadyMadeItem(
      bouquetId: bouquet.id,
      name: bouquet.name,
      imageUrl: bouquet.imageUrl,
      price: bouquet.price,
      fulfillmentType: _fulfillmentType,
      leadTimeBusinessDays: _deliveryMode == DeliveryMode.preOrder
          ? bouquet.leadTimeBusinessDays
          : 0,
    );

    final modeLabel = FulfillmentTypes.customerLabel(_fulfillmentType);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${bouquet.name} added as $modeLabel'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readyNow = _deliveryMode == DeliveryMode.readyNow;

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
              const Icon(
                Icons.location_on,
                color: AppColors.primaryRosewood,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _locatingGps ? 'Detecting location...' : _address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _modeButton(
                      '⚡ Ready to Send',
                      DeliveryMode.readyNow,
                    ),
                  ),
                  Expanded(
                    child: _modeButton('📅 Pre-Order', DeliveryMode.preOrder),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.softBlushStart, AppColors.softBlushEnd],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    readyNow
                        ? 'Need flowers urgently? 🌸'
                        : 'Planning something special? 📅',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    readyNow
                        ? 'These bouquets are already assembled and can be sent immediately.'
                        : 'Choose a design and we will prepare it within 1–3 business days.',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const BouquetBuilderScreen(),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryRosewood,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Build a custom bouquet • prepared in 1–3 business days',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final selected = _selectedCategory == category;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: AppColors.primaryRosewood,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textDark,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedCategory = category),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            Text(
              readyNow ? 'Ready to Send' : 'Available for Pre-Order',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bouquets')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load bouquets.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final bouquets =
                    (snapshot.data?.docs ?? const [])
                        .where(
                          (document) => document.data()['archived'] != true,
                        )
                        .map(
                          (document) => BouquetModel.fromMap(
                            document.data(),
                            document.id,
                          ),
                        )
                        .where(_belongsInSelectedMode)
                        .toList()
                      ..sort(
                        (a, b) => a.name.toLowerCase().compareTo(
                          b.name.toLowerCase(),
                        ),
                      );

                if (bouquets.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 42),
                    child: Center(
                      child: Text(
                        readyNow
                            ? 'No assembled bouquets are available in this category.'
                            : 'No bouquets are open for pre-order in this category.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.70,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: bouquets.length,
                  itemBuilder: (context, index) {
                    final bouquet = bouquets[index];
                    return _CustomerBouquetCard(
                      bouquet: bouquet,
                      readyNow: readyNow,
                      onAdd: () => _addBouquetToCart(bouquet),
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
    final selected = _deliveryMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _deliveryMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryRosewood : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CustomerBouquetCard extends StatelessWidget {
  const _CustomerBouquetCard({
    required this.bouquet,
    required this.readyNow,
    required this.onAdd,
  });

  final BouquetModel bouquet;
  final bool readyNow;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                bouquet.imageUrl.isEmpty
                    ? const Icon(Icons.local_florist, size: 50)
                    : Image.network(
                        bouquet.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.local_florist, size: 50),
                      ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FavouritesService().isBouquetFavourited(bouquet.id),
                    builder: (context, snapshot) {
                      final favourited = snapshot.data?.exists ?? false;
                      return IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            FavouritesService().toggleBouquetFavourite(
                              bouquetId: bouquet.id,
                              name: bouquet.name,
                              imageUrl: bouquet.imageUrl,
                              price: bouquet.price,
                            ),
                        icon: Icon(
                          favourited ? Icons.favorite : Icons.favorite_border,
                          size: 17,
                          color: AppColors.primaryRosewood,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bouquet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  readyNow
                      ? 'Ready for immediate delivery'
                      : 'Prepared in ${bouquet.leadTimeBusinessDays} business day${bouquet.leadTimeBusinessDays == 1 ? '' : 's'}',
                  maxLines: 2,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'RM ${bouquet.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.primaryRosewood,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onAdd,
                      borderRadius: BorderRadius.circular(20),
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primaryRosewood,
                        child: Icon(Icons.add, size: 17, color: Colors.white),
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
  }
}
