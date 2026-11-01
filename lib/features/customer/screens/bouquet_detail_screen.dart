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
  late bool _readyNow;
  late final FavouritesService _favourites =
      widget.favouritesService ?? FavouritesService();

  @override
  void initState() {
    super.initState();
    AppMonitoring.event('product_viewed');
    _readyNow =
        !(widget.initialFulfillmentType == FulfillmentTypes.preOrder &&
            widget.bouquet.availableForPreOrder) &&
        widget.bouquet.availableForReadyNow &&
        widget.bouquet.readyStock > 0;
  }

  Future<void> _add() async {
    final bouquet = widget.bouquet;
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
            fulfillmentType: _readyNow
                ? FulfillmentTypes.readyNow
                : FulfillmentTypes.preOrder,
            leadTimeBusinessDays: _readyNow ? 0 : bouquet.leadTimeBusinessDays,
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
    final readyAvailable =
        bouquet.availableForReadyNow && bouquet.readyStock > 0;
    final preorderAvailable = bouquet.availableForPreOrder;
    final cartCount = context.watch<CartProvider>().itemCount;

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
            child: AspectRatio(
              aspectRatio: 1.15,
              child: ColoredBox(
                color: AppColors.inputFill,
                child: bouquet.imageUrl.isEmpty
                    ? const Icon(
                        Icons.local_florist_outlined,
                        size: 90,
                        color: AppColors.primary,
                      )
                    : Image.network(
                        bouquet.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.local_florist_outlined,
                          size: 90,
                          color: AppColors.primary,
                        ),
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
                if (bouquet.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    bouquet.description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      height: 1.55,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'How would you like it?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (readyAvailable)
                  _FulfilmentOption(
                    selected: _readyNow,
                    icon: Icons.bolt_rounded,
                    title: 'Ready to send',
                    subtitle:
                        '${bouquet.readyStock} available; dispatch depends on a rider',
                    onTap: () => setState(() => _readyNow = true),
                  ),
                if (readyAvailable && preorderAvailable)
                  const SizedBox(height: 10),
                if (preorderAvailable)
                  _FulfilmentOption(
                    selected: !_readyNow,
                    icon: Icons.calendar_today_outlined,
                    title: 'Pre-order',
                    subtitle:
                        'Choose a date after ${bouquet.leadTimeBusinessDays < 2 ? 2 : bouquet.leadTimeBusinessDays} preparation days',
                    onTap: () => setState(() => _readyNow = false),
                  ),
                const SizedBox(height: 24),
                const _InfoRow(
                  icon: Icons.eco_outlined,
                  title: 'Arranged by hand',
                  subtitle:
                      'Each bouquet is prepared by the Bloom & Bunch florist team.',
                ),
                const SizedBox(height: 12),
                const _InfoRow(
                  icon: Icons.local_shipping_outlined,
                  title: 'Delivery across KL',
                  subtitle:
                      'Check delivery coverage, fees and estimated dispatch at checkout.',
                ),
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
            onPressed: readyAvailable || preorderAvailable ? _add : null,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(_readyNow ? 'Choose add-ons' : 'Choose add-ons & date'),
          ),
        ),
      ),
    );
  }
}

class _FulfilmentOption extends StatelessWidget {
  const _FulfilmentOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.secondarySurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.inputBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const AppTypography.label()),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const AppTypography.caption(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppColors.secondarySurface,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const AppTypography.label()),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
