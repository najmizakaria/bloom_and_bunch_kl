import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/store_details.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/delivery_job_model.dart';
import '../../../models/order_model.dart';

class RiderNavigation {
  static Future<void> _open(BuildContext context, Uri uri, String error) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  static Future<void> call(BuildContext context, OrderModel order) => _open(
    context,
    Uri(scheme: 'tel', path: order.recipientPhone),
    'Could not open the phone dialer.',
  );
  static Future<void> navigate(BuildContext context, OrderModel order) => _open(
    context,
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': order.latitude != null && order.longitude != null
          ? '${order.latitude},${order.longitude}'
          : order.deliveryAddress,
    }),
    'Could not open navigation. Use the written delivery address.',
  );
}

class RiderDeliveryDetails extends StatelessWidget {
  const RiderDeliveryDetails({super.key, required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final timing = DeliveryJobModel(
      orderId: order.orderId,
      deliveryArea: '',
      deliveryTimeSlot: order.deliveryTimeSlot,
      createdAt: order.createdAt,
      requestedDeliveryDate: order.requestedDeliveryDate,
      scheduledDeliveryDate: order.scheduledDeliveryDate,
      estimatedDispatchDate: order.estimatedDispatchDate,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delivery ${timing.reference}',
              style: const AppTypography.productTitle(),
            ),
            const SizedBox(height: 6),
            Text(
              order.orderStatus,
              style: const AppTypography.label(color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Deliver to',
              style: AppTypography.caption(color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            SelectableText(
              order.deliveryAddress.isEmpty
                  ? 'Address unavailable. Contact the store.'
                  : order.deliveryAddress,
              style: const AppTypography.sectionTitle(),
            ),
            const SizedBox(height: 12),
            Text(
              order.recipientName,
              style: const AppTypography.productTitle(),
            ),
            if (order.recipientPhone.isNotEmpty)
              SelectableText(order.recipientPhone),
            const SizedBox(height: 12),
            Text(timing.timingLabel(), style: const AppTypography.supporting()),
            if (timing.dateWarning() != null)
              Text(
                timing.dateWarning()!,
                style: const AppTypography.label(color: AppColors.primaryDark),
              ),
            if (order.deliveryNote.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery instructions',
                      style: AppTypography.label(),
                    ),
                    const SizedBox(height: 4),
                    Text(order.deliveryNote),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: order.deliveryAddress.isEmpty
                  ? null
                  : () => RiderNavigation.navigate(context, order),
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Navigate'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: order.recipientPhone.isEmpty
                  ? null
                  : () => RiderNavigation.call(context, order),
              icon: const Icon(Icons.call_outlined),
              label: const Text('Call recipient'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Text('Collect from', style: AppTypography.label()),
            const SizedBox(height: 4),
            const Text('${StoreDetails.name}\n${StoreDetails.pickupAddress}'),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Items to collect', style: AppTypography.label()),
              const SizedBox(height: 6),
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${item['quantity'] ?? 1} × ${item['name'] ?? 'Bouquet'}${item['type'] == 'addon' ? ' · Add-on' : ''}',
                  ),
                ),
            ],
            if (order.messageCard != null)
              const Text('Include the selected message card.'),
          ],
        ),
      ),
    );
  }
}
