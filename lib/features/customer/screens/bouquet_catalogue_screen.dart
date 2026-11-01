import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import '../../../core/services/bouquet_query.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import '../../../core/widgets/firestore_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/cart_provider.dart';
import '../../../core/services/favourites_service.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/product_components.dart';
import '../../../models/bouquet_model.dart';
import 'bouquet_detail_screen.dart';
import 'cart_screen.dart';

class BouquetCatalogueScreen extends StatefulWidget {
  const BouquetCatalogueScreen({
    super.key,
    this.initialQuery = '',
    this.initialCategory = 'All',
    this.initialReadyOnly = false,
    this.initialMode = BouquetMode.all,
  });
  final String initialCategory;
  final bool initialReadyOnly;
  final BouquetMode initialMode;

  final String initialQuery;

  @override
  State<BouquetCatalogueScreen> createState() => BouquetCatalogueScreenState();
}

class BouquetCatalogueScreenState extends State<BouquetCatalogueScreen> {
  static const _categories = [
    'All',
    'Birthday',
    'Anniversary',
    'Romance',
    'Sympathy',
  ];
  late final TextEditingController _searchController;
  String _query = '';
  String _category = 'All';
  BouquetMode _mode = BouquetMode.all;

  void selectFilters(String category, BouquetMode mode) => setState(() {
    _category = _categories.contains(category) ? category : 'All';
    _mode = mode;
  });
  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _mode = widget.initialReadyOnly ? BouquetMode.readyNow : widget.initialMode;
    _query = widget.initialQuery.trim().toLowerCase();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(BouquetModel bouquet) {
    if (!bouquet.isPublished) return false;
    if (_category != 'All' && bouquet.category != _category) {
      return false;
    }
    if (!matchesBouquetMode(bouquet, _mode)) {
      return false;
    }
    if (_query.isEmpty) return true;
    return bouquet.name.toLowerCase().contains(_query) ||
        bouquet.description.toLowerCase().contains(_query) ||
        bouquet.category.toLowerCase().contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text('Browse bouquets'),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FirestorePage(
        query: bouquetQuery(_category, _mode),
        pageBuilder: (context, docs, reload) {
          final bouquets =
              docs
                  .where((document) => document.data()['archived'] != true)
                  .map(
                    (document) =>
                        BouquetModel.fromMap(document.data(), document.id),
                  )
                  .where(_matches)
                  .toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search loaded bouquets or occasions',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ProductFilterBar(
                        children: [
                          ProductCategoryChip(
                            selected: _mode == BouquetMode.readyNow,
                            label: 'Ready now',
                            icon: Icons.bolt_rounded,
                            onSelected: (value) => selectFilters(
                              _category,
                              value ? BouquetMode.readyNow : BouquetMode.all,
                            ),
                          ),
                          ProductCategoryChip(
                            selected: _mode == BouquetMode.preOrder,
                            label: 'Pre-Order',
                            onSelected: (value) => selectFilters(
                              _category,
                              value ? BouquetMode.preOrder : BouquetMode.all,
                            ),
                          ),
                          ..._categories.map(
                            (category) => ProductCategoryChip(
                              selected: _category == category,
                              label: category,
                              onSelected: (_) => selectFilters(category, _mode),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SliverMainAxisGroup(
                slivers: [
                  if (bouquets.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No matching bouquets. Try changing your filters.',
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid.builder(
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
                      itemBuilder: (context, index) =>
                          _BouquetTile(bouquet: bouquets[index], mode: _mode),
                    ),
                  ),
                  SliverToBoxAdapter(child: reload),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BouquetTile extends StatelessWidget {
  const _BouquetTile({required this.bouquet, required this.mode});
  final BouquetMode mode;
  final BouquetModel bouquet;

  @override
  Widget build(BuildContext context) {
    final ready =
        mode != BouquetMode.preOrder &&
        bouquet.availableForReadyNow &&
        bouquet.readyStock > 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => BouquetDetailScreen(
              bouquet: bouquet,
              initialFulfillmentType: mode == BouquetMode.preOrder
                  ? 'pre_order'
                  : mode == BouquetMode.readyNow
                  ? 'ready_now'
                  : null,
            ),
          ),
        ),
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
                            final selected = snapshot.data?.exists ?? false;
                            return ProductFavouriteButton(
                              selected: selected,
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
                  const SizedBox(height: 6),
                  Text(
                    ready
                        ? 'Ready to send'
                        : '${bouquet.leadTimeBusinessDays < 2 ? 2 : bouquet.leadTimeBusinessDays} preparation days minimum',
                    style: AppTypography.caption(
                      color: ready
                          ? AppColors.availability
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RM ${bouquet.price.toStringAsFixed(2)}',
                    style: const AppTypography.price(color: AppColors.textDark),
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
