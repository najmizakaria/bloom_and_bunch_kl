import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// The same image surface for loaded, missing, and failed product images.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const placeholder = Center(
      child: Icon(
        Icons.local_florist_outlined,
        size: 48,
        color: AppColors.textMuted,
      ),
    );
    return ColoredBox(
      color: AppColors.inputFill,
      child: imageUrl.isEmpty
          ? placeholder
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class ProductFavouriteButton extends StatelessWidget {
  const ProductFavouriteButton({
    super.key,
    required this.selected,
    required this.onPressed,
  });

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: selected ? 'Remove from favourites' : 'Add to favourites',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        minimumSize: const Size(48, 48),
      ),
      onPressed: onPressed,
      icon: Icon(
        selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 20,
      ),
    );
  }
}

/// An intrinsic-height row keeps labels visible at large text sizes.
/// The persistent scrollbar makes overflowing categories discoverable.
class ProductFilterBar extends StatefulWidget {
  const ProductFilterBar({super.key, required this.children});

  final List<Widget> children;

  @override
  State<ProductFilterBar> createState() => _ProductFilterBarState();
}

class ProductCategoryChip extends StatelessWidget {
  const ProductCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cardWhite,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.inputBorder,
      ),
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 17,
              color: selected ? AppColors.onPrimary : AppColors.primary,
            ),
      label: Text(label),
      labelStyle: AppTypography.label(
        color: selected ? AppColors.onPrimary : AppColors.textDark,
      ),
      onSelected: onSelected,
    );
  }
}

class _ProductFilterBarState extends State<ProductFilterBar> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            for (var index = 0; index < widget.children.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              widget.children[index],
            ],
          ],
        ),
      ),
    );
  }
}

/// Presentation only: callers retain their existing quantity limits/actions.
class StemQuantityControl extends StatelessWidget {
  const StemQuantityControl({
    super.key,
    required this.count,
    required this.onRemove,
    required this.onAdd,
    required this.onEdit,
  });

  final int count;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Remove one stem',
          onPressed: onRemove,
          icon: const Icon(Icons.remove),
        ),
        TextButton(
          onPressed: onEdit,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text('$count', style: const AppTypography.productTitle()),
        ),
        IconButton.filledTonal(
          tooltip: 'Add one stem',
          onPressed: onAdd,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class BouquetBuilderFooter extends StatelessWidget {
  const BouquetBuilderFooter({
    super.key,
    required this.stems,
    required this.totalPrice,
    required this.onSave,
    required this.onAdd,
  });

  final int stems;
  final double totalPrice;
  final VoidCallback onSave;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final save = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onPressed: onSave,
      icon: const Icon(Icons.favorite_border),
      label: const Text('Save Recipe'),
    );
    final add = FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onPressed: onAdd,
      icon: const Icon(Icons.shopping_cart_outlined),
      label: const Text('Add to Cart'),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.inputBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 4,
                spacing: 16,
                children: [
                  Text(
                    '$stems stems',
                    style: const AppTypography.caption(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    'RM ${totalPrice.toStringAsFixed(2)}',
                    style: const AppTypography.total(color: AppColors.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 340 ||
                      MediaQuery.textScalerOf(context).scale(15) > 19) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [save, const SizedBox(height: 8), add],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: save),
                      const SizedBox(width: 12),
                      Expanded(child: add),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
