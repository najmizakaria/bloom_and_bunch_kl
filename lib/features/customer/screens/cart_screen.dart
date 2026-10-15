import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/fulfillment_constants.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
                  child: Text(cart.errorMessage!),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
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
                                    modeLabel,
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
                                      '${item.leadTimeBusinessDays} business day preparation',
                                      style: const AppTypography.caption(
                                        color: AppColors.textMuted,
                                      ),
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
                                      onPressed: () => context
                                          .read<CartProvider>()
                                          .decrementQuantity(item.id),
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
                                  onPressed: () => context
                                      .read<CartProvider>()
                                      .removeItem(item.id),
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
                              const Text(
                                'Items subtotal',
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
                            'Review your total and payment details at checkout. Ready and made-to-order bouquets travel separately.',
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
                              onPressed: () => Navigator.push(
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
