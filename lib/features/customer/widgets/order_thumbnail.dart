import 'package:flutter/material.dart';

import '../../../core/constants/fulfillment_constants.dart';
import '../../../core/theme/app_colors.dart';

/// Uses the photo saved at checkout, even if the catalogue changes later.
class OrderThumbnail extends StatelessWidget {
  const OrderThumbnail({super.key, required this.items});

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final orderItems = items.whereType<Map>();
    bool isCustom(Map item) =>
        item['fulfillmentType'] == FulfillmentTypes.custom ||
        item['type'] == 'custom';
    final catalogueItems = orderItems.where((item) => !isCustom(item));
    final customOnly = orderItems.isNotEmpty && catalogueItems.isEmpty;
    // A mixed planned order can contain custom and catalogue bouquets. Show a
    // catalogue photo whenever one is available, regardless of item order.
    final photographedItems = catalogueItems.where(
      (item) =>
          item['imageUrl'] is String &&
          (item['imageUrl'] as String).trim().isNotEmpty,
    );
    final item = photographedItems.firstOrNull;
    final imageUrl = (item?['imageUrl'] as String?)?.trim();
    final name = item?['name'];
    final label = customOnly
        ? 'Custom bouquet'
        : name is String && name.trim().isNotEmpty
        ? 'Photo of $name'
        : 'Bouquet photo';

    final placeholder = Semantics(
      image: true,
      label: customOnly ? label : 'Bouquet photo unavailable',
      child: Center(
        child: Icon(
          customOnly ? Icons.local_florist_outlined : Icons.image_outlined,
          size: 26,
          color: customOnly ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );

    return Tooltip(
      message: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(
          dimension: 54,
          child: ColoredBox(
            color: AppColors.secondarySurface,
            child: imageUrl == null
                ? placeholder
                : Image.network(
                    imageUrl,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    semanticLabel: label,
                    errorBuilder: (_, _, _) => placeholder,
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : placeholder,
                  ),
          ),
        ),
      ),
    );
  }
}
