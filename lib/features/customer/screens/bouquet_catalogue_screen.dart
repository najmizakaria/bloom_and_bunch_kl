import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import '../../../core/services/bouquet_query.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
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
  static const _limit = 40;
  final List<DocumentSnapshot<Map<String, dynamic>>?> _starts = [null];
  late Stream<QuerySnapshot<Map<String, dynamic>>> _bouquetsStream =
      _watchBouquets();
  Stream<QuerySnapshot<Map<String, dynamic>>> _watchBouquets() {
    var query = bouquetQuery(_category, _mode);
    if (_starts.last != null) query = query.startAfterDocument(_starts.last!);
    return query.limit(_limit + 1).snapshots();
  }

  Widget _pageControls(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        children: [
          TextButton(
            onPressed: _starts.length == 1
                ? null
                : () => setState(() {
                    _starts.removeLast();
                    _bouquetsStream = _watchBouquets();
                  }),
            child: const Text('Previous'),
          ),
          Text('Page ${_starts.length} · search applies to this page'),
          TextButton(
            onPressed: docs.length <= _limit
                ? null
                : () => setState(() {
                    _starts.add(docs[_limit - 1]);
                    _bouquetsStream = _watchBouquets();
                  }),
            child: const Text('Next'),
          ),
        ],
      ),
    ),
  );
  String _query = '';
  String _category = 'All';
  BouquetMode _mode = BouquetMode.all;

  void selectFilters(String category, BouquetMode mode) => setState(() {
    _category = _categories.contains(category) ? category : 'All';
    _mode = mode;
    _starts.clear();
    _starts.add(null);
    _bouquetsStream = _watchBouquets();
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
      body: CustomScrollView(
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
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _bouquetsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: _CatalogueMessage(
                    onRetry: () =>
                        setState(() => _bouquetsStream = _watchBouquets()),
                    icon: Icons.cloud_off_outlined,
                    title: 'Bouquets could not be loaded',
                    message: 'Check your connection and try again.',
                  ),
                );
              }

              final bouquets =
                  (snapshot.data?.docs ?? const [])
                      .take(_limit)
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

              return SliverMainAxisGroup(
                slivers: [
                  if (bouquets.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No matching bouquets on this page. Check Next or change your filters.',
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
                  _pageControls(snapshot.data?.docs ?? const []),
                ],
              );
            },
          ),
        ],
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
                        : '${bouquet.leadTimeBusinessDays < 2 ? 2 : bouquet.leadTimeBusinessDays} business days minimum',
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

class _CatalogueMessage extends StatelessWidget {
  const _CatalogueMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            Icon(icon, size: 52, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
