import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import '../../../core/services/bouquet_query.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/fulfillment_constants.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/address_service.dart';
import '../../../core/services/favourites_service.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/product_components.dart';
import '../../../models/bouquet_model.dart';
import '../../../models/saved_address_model.dart';
import 'address_book_screen.dart';
import 'bouquet_builder_screen.dart';
import 'bouquet_catalogue_screen.dart';
import 'bouquet_detail_screen.dart';
import 'cart_screen.dart';
import 'bouquet_options_screen.dart';
import '../../../models/cart_item_model.dart';

enum DeliveryMode { readyNow, preOrder }

class CustomerHomeScreen extends StatefulWidget {
  final void Function(String category, BouquetMode mode)? onBrowse;
  const CustomerHomeScreen({super.key, this.onBrowse});

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

  late Stream<QuerySnapshot<Map<String, dynamic>>> _bouquetsStream =
      _watchBouquets();
  BouquetMode get _browseMode => _deliveryMode == DeliveryMode.readyNow
      ? BouquetMode.readyNow
      : BouquetMode.preOrder;
  Stream<QuerySnapshot<Map<String, dynamic>>> _watchBouquets() =>
      bouquetQuery(_selectedCategory, _browseMode).limit(20).snapshots();
  void _openBrowse() {
    if (widget.onBrowse != null) {
      widget.onBrowse!(_selectedCategory, _browseMode);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => BouquetCatalogueScreen(
            initialCategory: _selectedCategory,
            initialMode: _browseMode,
          ),
        ),
      );
    }
  }

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
      try {
        await AddressService().setDefault(address.id);
        if (mounted) setState(() => _address = address.address);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not select your delivery address. Please retry.',
              ),
            ),
          );
        }
      }
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
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BouquetOptionsScreen(
          bouquet: CartItemModel(
            id: 'bouquet_${DateTime.now().microsecondsSinceEpoch}',
            type: 'ready',
            bouquetId: bouquet.id,
            name: bouquet.name,
            imageUrl: bouquet.imageUrl,
            unitPrice: bouquet.price,
            fulfillmentType: _fulfillmentType,
            leadTimeBusinessDays: _deliveryMode == DeliveryMode.preOrder
                ? bouquet.leadTimeBusinessDays
                : 0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readyNow = _deliveryMode == DeliveryMode.readyNow;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        titleSpacing: 16,
        title: InkWell(
          onTap: _openAddressSheet,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _locatingGps ? 'Detecting location...' : _address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const AppTypography.label(color: AppColors.textDark),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
            icon: Badge(
              isLabelVisible: context.watch<CartProvider>().itemCount > 0,
              label: Text('${context.watch<CartProvider>().itemCount}'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find the perfect flowers',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              readOnly: true,
              onTap: () {
                if (widget.onBrowse != null) {
                  widget.onBrowse!(_selectedCategory, _browseMode);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => BouquetCatalogueScreen(
                        initialCategory: _selectedCategory,
                        initialMode: _browseMode,
                      ),
                    ),
                  );
                }
              },
              decoration: const InputDecoration(
                hintText: 'Search bouquets or occasions',
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(height: 18),
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
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    ImageIcon(
                      AssetImage('assets/icons/flower_bouquet.png'),
                      color: AppColors.onPrimary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Let’s build your own bouquet',
                        style: AppTypography.label(color: AppColors.onPrimary),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.onPrimary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Categories', style: AppTypography.sectionTitle()),
            const SizedBox(height: 10),
            ProductFilterBar(
              children: _categories
                  .map(
                    (category) => ProductCategoryChip(
                      label: category,
                      selected: _selectedCategory == category,
                      onSelected: (_) => setState(() {
                        _selectedCategory = category;
                        _bouquetsStream = _watchBouquets();
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text(
              readyNow ? 'Ready to Send' : 'Available for Pre-Order',
              style: const AppTypography.sectionTitle(),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _openBrowse,
              child: const Text(
                'Browse all bouquets · preview shows up to 20 products',
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _bouquetsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      children: [
                        const Text(
                          'Unable to load bouquets. Check your connection.',
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _bouquetsStream = _watchBouquets(),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
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
                            ? 'No available bouquets in this preview. Browse all to check more products.'
                            : 'No pre-order bouquets in this preview. Browse all to check more products.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width < 360
                        ? 1
                        : 2,
                    mainAxisExtent:
                        300 +
                        (MediaQuery.textScalerOf(context).scale(140) - 140),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: bouquets.length,
                  itemBuilder: (context, index) {
                    final bouquet = bouquets[index];
                    return _CustomerBouquetCard(
                      bouquet: bouquet,
                      readyNow: readyNow,
                      onOpen: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => BouquetDetailScreen(
                            bouquet: bouquet,
                            initialFulfillmentType: _fulfillmentType,
                          ),
                        ),
                      ),
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

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _deliveryMode = mode;
            _bouquetsStream = _watchBouquets();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.inputBorder,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.16 : 0.09),
                  blurRadius: selected ? 9 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.label(
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
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
    required this.onOpen,
    required this.onAdd,
  });

  final BouquetModel bouquet;
  final bool readyNow;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(imageUrl: bouquet.imageUrl),
                  Positioned(
                    top: 8,
                    right: 8,
                    child:
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FavouritesService().isBouquetFavourited(
                            bouquet.id,
                          ),
                          builder: (context, snapshot) {
                            final favourited = snapshot.data?.exists ?? false;
                            return ProductFavouriteButton(
                              selected: favourited,
                              onPressed: () => ActionFeedback.run(
                                context,
                                () =>
                                    FavouritesService().toggleBouquetFavourite(
                                      bouquetId: bouquet.id,
                                      name: bouquet.name,
                                      imageUrl: bouquet.imageUrl,
                                      price: bouquet.price,
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bouquet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const AppTypography.productTitle(
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    readyNow
                        ? 'Ready; dispatch depends on rider availability'
                        : 'Choose a date · ${bouquet.leadTimeBusinessDays < 2 ? 2 : bouquet.leadTimeBusinessDays} business days minimum',
                    maxLines: 2,
                    style: const AppTypography.caption(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'RM ${bouquet.price.toStringAsFixed(2)}',
                          style: const AppTypography.price(
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onAdd,
                        borderRadius: BorderRadius.circular(20),
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary,
                          child: Icon(
                            Icons.add,
                            size: 17,
                            color: AppColors.onPrimary,
                          ),
                        ),
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
  }
}
