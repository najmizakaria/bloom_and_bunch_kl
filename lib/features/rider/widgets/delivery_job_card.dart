import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/malaysia_time.dart';
import '../../../models/delivery_job_model.dart';

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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  job.readyForPickup
                      ? 'Ready for pickup'
                      : 'Waiting for preparation',
                  style: const AppTypography.badge(color: AppColors.primary),
                ),
              ),
              Text(
                job.reference,
                style: const AppTypography.label(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Deliver to',
            style: AppTypography.caption(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(job.destination, style: const AppTypography.sectionTitle()),
          if (!job.hasDeliveryAddress &&
              job.state.isNotEmpty &&
              job.state != job.locality)
            Text(
              job.state,
              style: const AppTypography.body(color: AppColors.textMuted),
            ),
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
          if (job.itemCount > 0) ...[
            const SizedBox(height: 12),
            _Detail(
              icon: Icons.shopping_bag_outlined,
              value:
                  '${job.itemCount} ${job.itemCount == 1 ? 'item' : 'items'} to collect',
            ),
          ],
          if (job.dateWarning() != null || job.areaNeedsConfirmation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                [
                  if (job.dateWarning() != null) '${job.dateWarning()}.',
                  if (job.areaNeedsConfirmation)
                    'Delivery area needs confirmation.',
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

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.value, this.label});
  final IconData icon;
  final String value;
  final String? label;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: AppColors.primary),
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
