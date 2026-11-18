import 'package:flutter/material.dart';

import '../../../core/constants/fulfillment_constants.dart';
import '../../../core/theme/app_colors.dart';

enum _TrackingStage {
  received('Order received'),
  payment('Payment verification'),
  preparation('Bouquet being prepared'),
  ready('Ready to ship'),
  assigned('Rider assigned · awaiting collection'),
  delivering('On the way'),
  delivered('Delivered · awaiting your confirmation'),
  confirmed('Receipt confirmed');

  const _TrackingStage(this.label);
  final String label;
}

class OrderTrackingProgress extends StatelessWidget {
  const OrderTrackingProgress({
    super.key,
    required this.status,
    required this.paymentStatus,
    required this.receiptConfirmed,
    this.fulfillmentType,
  });

  final String status;
  final String? paymentStatus, fulfillmentType;
  final bool receiptConfirmed;

  @override
  Widget build(BuildContext context) {
    final current = OrderStatuses.normalize(status);
    final cancelled = current == OrderStatuses.cancelled;
    final expired = paymentStatus == 'expired';
    final pending = paymentStatus == 'pending';
    final readyToSend = fulfillmentType == FulfillmentTypes.readyNow;
    final legacyDelivered =
        current == OrderStatuses.delivered ||
        (current == OrderStatuses.completed && !receiptConfirmed);
    final active = switch (current) {
      _ when pending => _TrackingStage.payment,
      OrderStatuses.awaitingPreparation when !readyToSend =>
        _TrackingStage.preparation,
      OrderStatuses.processing when !readyToSend => _TrackingStage.preparation,
      OrderStatuses.readyForDelivery ||
      OrderStatuses.processing => _TrackingStage.ready,
      OrderStatuses.riderAssigned => _TrackingStage.assigned,
      OrderStatuses.outForDelivery => _TrackingStage.delivering,
      OrderStatuses.awaitingConfirmation ||
      OrderStatuses.delivered => _TrackingStage.delivered,
      OrderStatuses.completed when receiptConfirmed => _TrackingStage.confirmed,
      OrderStatuses.completed => _TrackingStage.delivered,
      _ => _TrackingStage.received,
    };
    final stages = [
      for (final stage in _TrackingStage.values)
        if (!(readyToSend && stage == _TrackingStage.preparation) &&
            !(legacyDelivered && stage == _TrackingStage.confirmed))
          stage,
    ];
    final completeActive =
        active == _TrackingStage.confirmed ||
        (active == _TrackingStage.delivered && legacyDelivered);
    final activeLabel = switch (active) {
      _TrackingStage.preparation
          when current == OrderStatuses.awaitingPreparation =>
        'Awaiting bouquet preparation',
      _TrackingStage.delivered when legacyDelivered => 'Delivered',
      _ => active.label,
    };
    final title = cancelled
        ? 'Order cancelled'
        : expired
        ? 'Payment expired'
        : legacyDelivered && !pending
        ? OrderStatuses.label(current)
        : activeLabel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (!cancelled && !expired) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (stages.indexOf(active) + 1) / stages.length,
                minHeight: 4,
                color: AppColors.primary,
                backgroundColor: AppColors.softBlushEnd,
              ),
              const SizedBox(height: 8),
              for (final stage in stages)
                _ProgressRow(
                  label: stage == active
                      ? activeLabel
                      : stage == _TrackingStage.payment &&
                            paymentStatus == 'not_required'
                      ? 'Payment not required'
                      : stage.label,
                  complete:
                      stage.index < active.index ||
                      (stage == active && completeActive),
                  current: stage == active,
                ),
              if (pending)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.softBlushEnd,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'We’re checking your payment! As soon as it’s confirmed, our florists will start arranging your flowers.',
                      style: TextStyle(color: AppColors.primaryDark),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.complete,
    required this.current,
  });

  final String label;
  final bool complete, current;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    label:
        '$label, ${current
            ? 'current step'
            : complete
            ? 'complete'
            : 'upcoming'}',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            complete
                ? Icons.check_circle
                : current
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: AppColors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                if (current)
                  Text(
                    'Current status',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
