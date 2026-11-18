import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/malaysia_time.dart';
import '../../../core/utils/order_tracking_display.dart';
import '../../../models/delivery_job_model.dart';
import 'rider_delivery_details.dart';

class DeliveryJobCard extends StatelessWidget {
  const DeliveryJobCard({
    super.key,
    required this.job,
    this.onView,
    this.detailed = false,
  });
  final DeliveryJobModel job;
  final VoidCallback? onView;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final area = job.destinationArea;
    final address = trackingAddress(
      job.deliveryAddress,
      keepMapCodeOnly: detailed,
    );
    final showDateNotes = detailed || job.hasRequestedDate;
    final dateWarning = showDateNotes ? job.dateWarning() : null;
    final pay = job.riderPaySen;
    final statusColor = job.readyForPickup
        ? AppColors.statusReady
        : AppColors.statusPreparing;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              job.reference,
              style: const AppTypography.label(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        job.readyForPickup
                            ? Icons.check_circle_outline
                            : Icons.schedule_outlined,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          job.readyForPickup
                              ? 'Ready for pickup'
                              : 'Waiting for preparation',
                          style: AppTypography.productTitle(color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
                if (pay != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Rider pay',
                          style: AppTypography.label(
                            color: AppColors.onPrimary,
                          ),
                        ),
                        Text(
                          'RM ${(pay / 100).toStringAsFixed(2)}',
                          style: const AppTypography.total(
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'Rider pay not set',
                    style: AppTypography.label(color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Deliver to',
              style: AppTypography.caption(color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              !detailed && address.isNotEmpty
                  ? address
                  : area ?? 'Area needs confirmation',
              style: const AppTypography.sectionTitle(),
            ),
            if (detailed && address.isNotEmpty)
              Text(
                address,
                style: const AppTypography.body(color: AppColors.textMuted),
              ),
            if (area != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      RiderNavigation.previewRoute(context, job, area),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Open in Maps'),
                ),
              ),
              const Text(
                'Approximate drop-off area',
                style: AppTypography.caption(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            _Detail(
              icon: Icons.storefront_outlined,
              label: 'Collect from',
              value: detailed
                  ? '${job.pickupName}\n${job.pickupAddress}'
                  : job.pickupName,
            ),
            const SizedBox(height: 12),
            _Detail(icon: Icons.schedule_outlined, value: job.timingLabel()),
            if (showDateNotes && job.earlyDispatchDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Released for early delivery: ${job.earlyDispatchDate}',
                style: const AppTypography.label(color: AppColors.primaryDark),
              ),
            ],
            if (job.itemCount > 0) ...[
              const SizedBox(height: 12),
              _Detail(
                icon: Icons.shopping_bag_outlined,
                value:
                    '${job.itemCount} ${job.itemCount == 1 ? 'item' : 'items'} to collect',
              ),
            ],
            if (dateWarning != null || area == null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  [
                    if (dateWarning != null) '$dateWarning.',
                    'Confirm details with the store before accepting.',
                  ].join(' '),
                  style: const AppTypography.caption(
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
            if (detailed) ...[
              const SizedBox(height: 16),
              Text(
                'Ordered ${malaysiaTime(job.createdAt)}',
                style: const AppTypography.caption(color: AppColors.textMuted),
              ),
            ] else ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View delivery'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.value, this.label});
  final IconData icon;
  final String value;
  final String? label;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.softBlushEnd,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 22, color: AppColors.primaryDark),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null)
              Text(
                label!,
                style: const AppTypography.caption(color: AppColors.textMuted),
              ),
            Text(value, style: const AppTypography.supporting()),
          ],
        ),
      ),
    ],
  );
}
