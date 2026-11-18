import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/fulfillment_constants.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/favourites_service.dart';
import '../../../core/services/app_monitoring.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bouquet_model.dart';
import 'cart_screen.dart';
import 'bouquet_options_screen.dart';
import '../../../models/cart_item_model.dart';

class BouquetDetailScreen extends StatefulWidget {
  const BouquetDetailScreen({
    super.key,
    required this.bouquet,
    this.initialFulfillmentType,
    this.favouritesService,
    this.optionsBuilder,
  });
  final BouquetModel bouquet;
  final String? initialFulfillmentType;
  final FavouritesService? favouritesService;
  final Widget Function(CartItemModel)? optionsBuilder;

  @override
  State<BouquetDetailScreen> createState() => _BouquetDetailScreenState();
}

class _BouquetDetailScreenState extends State<BouquetDetailScreen> {
  late final bool _readyNow;
  bool get _readyAvailable =>
      widget.bouquet.availableForReadyNow && widget.bouquet.readyStock > 0;
  late final FavouritesService _favourites =
      widget.favouritesService ?? FavouritesService();

  @override
  void initState() {
    super.initState();
    AppMonitoring.event('product_viewed');
    _readyNow =
        !(widget.initialFulfillmentType == FulfillmentTypes.preOrder &&
            widget.bouquet.availableForPreOrder) &&
        _readyAvailable;
  }

  Future<void> _add() async {
    final bouquet = widget.bouquet;
    final readyNow = _readyAvailable && bouquet.availableForPreOrder
        ? await showDialog<bool>(
            context: context,
            builder: (dialog) => SimpleDialog(
              title: const Text('Choose a delivery option'),
              children: [
                for (final ready in [_readyNow, !_readyNow])
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialog, ready),
                    child: Text(ready ? 'Ready to send' : 'Pre-order'),
                  ),
              ],
            ),
          )
        : _readyNow;
    if (!mounted || readyNow == null) return;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) {
          final draft = CartItemModel(
            id: 'bouquet_${DateTime.now().microsecondsSinceEpoch}',
            type: 'ready',
            bouquetId: bouquet.id,
            name: bouquet.name,
            imageUrl: bouquet.imageUrl,
            unitPrice: bouquet.price,
            fulfillmentType: readyNow
                ? FulfillmentTypes.readyNow
                : FulfillmentTypes.preOrder,
            leadTimeBusinessDays: readyNow ? 0 : bouquet.leadTimeBusinessDays,
          );
          return widget.optionsBuilder?.call(draft) ??
              BouquetOptionsScreen(bouquet: draft);
        },
      ),
    );
    if (added == true) AppMonitoring.event('cart_added');
  }

  @override
  Widget build(BuildContext context) {
    final bouquet = widget.bouquet;
    final description = bouquet.description.trim();
    final cartCount = context.watch<CartProvider>().itemCount;
    const imagePlaceholder = AspectRatio(
      aspectRatio: 1.15,
      child: Icon(
        Icons.local_florist_outlined,
        size: 90,
        color: AppColors.primary,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('Bouquet details'),
        actions: [
          StreamBuilder(
            stream: _favourites.isBouquetFavourited(bouquet.id),
            builder: (context, snapshot) {
              final selected = snapshot.data?.exists ?? false;
              return IconButton(
                tooltip: selected
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                onPressed: () => ActionFeedback.run(
                  context,
                  () => _favourites.toggleBouquetFavourite(
                    bouquetId: bouquet.id,
                    name: bouquet.name,
                    imageUrl: bouquet.imageUrl,
                    price: bouquet.price,
                  ),
                ),
                icon: Icon(
                  selected
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
              );
            },
          ),
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
            child: ColoredBox(
              color: AppColors.inputFill,
              child: bouquet.imageUrl.isEmpty
                  ? imagePlaceholder
                  : ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height,
                      ),
                      child: Image.network(
                        bouquet.imageUrl,
                        fit: BoxFit.contain,
                        frameBuilder: (_, child, frame, _) =>
                            frame == null ? imagePlaceholder : child,
                        errorBuilder: (_, _, _) => imagePlaceholder,
                      ),
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            sliver: SliverList.list(
              children: [
                Text(
                  bouquet.category.toUpperCase(),
                  style: const AppTypography.badge(
                    color: AppColors.primary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bouquet.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'RM ${bouquet.price.toStringAsFixed(2)}',
                  style: const AppTypography.total(color: AppColors.primary),
                ),
                if (description.isNotEmpty) ...[
                  const Divider(height: 24, color: AppColors.inputBorder),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      height: 1.55,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.inputBorder)),
          ),
          child: FilledButton.icon(
            onPressed: _readyAvailable || bouquet.availableForPreOrder
                ? _add
                : null,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(
              _readyAvailable ? 'Choose add-ons' : 'Choose add-ons & date',
            ),
          ),
        ),
      ),
    );
  }
}
