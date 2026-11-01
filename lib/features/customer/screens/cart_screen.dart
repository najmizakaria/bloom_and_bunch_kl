import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/fulfillment_constants.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'checkout_screen.dart';
import 'message_card_screen.dart';
import '../widgets/delivery_date_picker.dart';
import '../../../models/cart_item_model.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _remove(
    BuildContext context,
    CartProvider cart,
    CartItemModel item,
  ) async {
    final others = cart.items.where(
      (i) =>
          i.id != item.id &&
          i.type != 'addon' &&
          i.deliveryGroupKey == item.deliveryGroupKey,
    );
    final addons = cart.items
        .where(
          (i) =>
              i.type == 'addon' && i.deliveryGroupKey == item.deliveryGroupKey,
        )
        .toList();
    if (item.type != 'addon' && others.isEmpty && addons.isNotEmpty) {
      final destinations = cart.items
          .where(
            (i) =>
                i.type != 'addon' &&
                i.deliveryGroupKey != 'planned' &&
                i.deliveryGroupKey != item.deliveryGroupKey,
          )
          .map((i) => i.deliveryGroupKey)
          .toSet();
      final choice = await showDialog<String>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: const Text('What about the add-ons?'),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('These add-ons need a bouquet in their delivery.'),
            ),
            for (final group in destinations)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialog, group),
                child: Text(
                  'Move to ${group == 'ready_now' ? 'earliest delivery' : group}',
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, 'remove'),
              child: const Text('Remove bouquet and its add-ons'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Keep items'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      for (final addon in addons) {
        if (choice == 'remove') {
          cart.removeItem(addon.id);
        } else {
          cart.moveAddon(addon.id, choice);
        }
      }
    }
    cart.removeItem(item.id);
  }

  Widget _delivery(BuildContext context, CartProvider cart, String group) {
    final card = cart.messageCards[group],
        items = cart.items.where((i) => i.deliveryGroupKey == group).toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (group != 'ready_now') ...[
              Text(
                group == 'planned'
                    ? 'Choose delivery date'
                    : 'Delivery · $group',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              OutlinedButton.icon(
                onPressed: cart.hasPendingCheckout
                    ? null
                    : () async {
                        final date = await chooseDeliveryDate(context, items);
                        if (date != null) cart.changeGroupDate(group, date);
                      },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  group == 'planned' ? 'Choose date' : 'Change delivery date',
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (card != null) ...[
              MessageCardPreview(
                designName: (card['designName'] ?? 'Selected design')
                    .toString(),
                imageUrl: (card['imageUrl'] ?? '').toString(),
                message: (card['message'] ?? '').toString(),
                senderName: (card['senderName'] ?? '').toString(),
              ),
              Text(
                'Card: ${(card['price'] as num? ?? 0) == 0 ? 'Free' : 'RM ${(card['price'] as num).toStringAsFixed(2)}'}',
              ),
            ],
            TextButton.icon(
              onPressed: cart.hasPendingCheckout
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MessageCardScreen(group: group),
                      ),
                    ),
              icon: const Icon(Icons.mail_outline),
              label: Text(
                card == null
                    ? 'Add a message card (optional)'
                    : 'Edit message card',
              ),
            ),
            if (card != null)
              TextButton(
                onPressed: cart.hasPendingCheckout
                    ? null
                    : () => cart.setMessageCard(group, null),
                child: const Text('Remove message card'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('Your cart'),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cart.isEmpty &&
              cart.cloudSyncEnabled &&
              cart.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cart.errorMessage!),
                    TextButton(
                      onPressed: () async {
                        try {
                          await cart.reloadCloud();
                        } catch (_) {
                          /* Keep the draft available for another retry. */
                        }
                      },
                      child: const Text('Reload account cart'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (cart.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 64,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Your cart is empty',
                      style: AppTypography.productTitle(),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              if (cart.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(cart.errorMessage!),
                      if (cart.cloudSyncEnabled)
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () async {
                                try {
                                  await cart.retrySync();
                                } catch (_) {
                                  /* Error is displayed by the provider. */
                                }
                              },
                              child: const Text('Retry sync'),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await cart.reloadCloud();
                                } catch (_) {
                                  /* Keep the current draft on failure. */
                                }
                              },
                              child: const Text('Reload account cart'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length + cart.deliveryGroups.length,
                  itemBuilder: (context, index) {
                    if (index >= cart.items.length) {
                      return Padding(
                        padding: EdgeInsets.only(
                          top: index == cart.items.length ? 20 : 0,
                          bottom: 12,
                        ),
                        child: _delivery(
                          context,
                          cart,
                          cart.deliveryGroups[index - cart.items.length],
                        ),
                      );
                    }
                    final item = cart.items[index];
                    final modeLabel = FulfillmentTypes.customerLabel(
                      item.fulfillmentType,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: item.imageUrl.isNotEmpty
                                    ? Image.network(
                                        item.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.local_florist,
                                                  color: AppColors.primary,
                                                ),
                                      )
                                    : const ColoredBox(
                                        color: AppColors.secondarySurface,
                                        child: Icon(
                                          Icons.local_florist,
                                          color: AppColors.primary,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const AppTypography.productTitle(),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.type == 'addon' ? 'Add-on' : modeLabel,
                                    style: AppTypography.badge(
                                      color:
                                          item.fulfillmentType ==
                                              FulfillmentTypes.readyNow
                                          ? AppColors.primary
                                          : AppColors.primaryDark,
                                    ),
                                  ),
                                  if (item.leadTimeBusinessDays > 0)
                                    Text(
                                      '${item.leadTimeBusinessDays} preparation days',
                                      style: const AppTypography.caption(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  if (item.requestedDeliveryDate != null)
                                    Text(
                                      'Delivery: ${item.requestedDeliveryDate}',
                                    ),
                                  if (item.type == 'custom') ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.wrapper} • ${item.ribbon}',
                                      style: const AppTypography.caption(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 7),
                                  Text(
                                    'RM ${item.unitPrice.toStringAsFixed(2)}',
                                    style: const AppTypography.price(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        if (item.quantity == 1) {
                                          _remove(context, cart, item);
                                        } else {
                                          cart.decrementQuantity(item.id);
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 20,
                                      ),
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: const AppTypography.label(),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => context
                                          .read<CartProvider>()
                                          .incrementQuantity(item.id),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () => _remove(context, cart, item),
                                  child: const Text(
                                    'Remove',
                                    style: AppTypography.caption(
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      top: BorderSide(color: AppColors.inputBorder),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.09),
                        blurRadius: 12,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            runSpacing: 8,
                            spacing: 16,
                            children: [
                              Text(
                                cart.messageCards.isEmpty
                                    ? 'Items subtotal'
                                    : 'Items and cards',
                                style: AppTypography.body(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(
                                'RM ${cart.totalPrice.toStringAsFixed(2)}',
                                style: const AppTypography.total(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Items and cards share one payment and receipt. Different dates are shown as separate deliveries.',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(48, 52),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                              ),
                              onPressed:
                                  cart.needsDeliveryDates ||
                                      !cart.cardsComplete ||
                                      cart.hasOrphanAddons
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => const CheckoutScreen(),
                                      ),
                                    ),
                              child: const Text(
                                'Proceed to Checkout',
                                style: AppTypography.button(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
