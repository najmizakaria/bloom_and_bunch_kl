import 'package:flutter/material.dart';
import '../constants/fulfillment_constants.dart';
import 'action_confirmation.dart';

class DeliveryProgress extends StatelessWidget {
  final String status, fulfillmentType;
  final bool receiptConfirmed;
  const DeliveryProgress({
    super.key,
    required this.status,
    required this.fulfillmentType,
    this.receiptConfirmed = false,
  });
  @override
  Widget build(BuildContext context) {
    final current = OrderStatuses.normalize(status);
    if (current == OrderStatuses.cancelled) {
      return const ListTile(
        leading: Icon(Icons.cancel_outlined),
        title: Text('Order cancelled'),
      );
    }
    if (current == OrderStatuses.completed && !receiptConfirmed) {
      return const ListTile(
        leading: Icon(Icons.check_circle),
        title: Text('Completed (legacy record)'),
        subtitle: Text(
          'Customer receipt confirmation was not recorded by the older workflow.',
        ),
      );
    }
    if (current == OrderStatuses.delivered) {
      return const ListTile(
        leading: Icon(Icons.check_circle),
        title: Text('Delivered (legacy record)'),
        subtitle: Text(
          'Customer receipt confirmation was not recorded by the older workflow.',
        ),
      );
    }
    final stages = [
      OrderStatuses.awaitingPreparation,
      OrderStatuses.processing,
      OrderStatuses.readyForDelivery,
      OrderStatuses.riderAssigned,
      OrderStatuses.outForDelivery,
      OrderStatuses.awaitingConfirmation,
      OrderStatuses.completed,
    ];
    final index = stages.indexOf(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          OrderStatuses.label(current, receiptConfirmed: receiptConfirmed),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (index >= 0)
          LinearProgressIndicator(
            value: (index + 1) / stages.length,
            semanticsLabel: 'Delivery progress',
          ),
        const SizedBox(height: 8),
        for (var i = 0; i < stages.length; i++)
          ListTile(
            leading: Icon(
              i <= index ? Icons.check_circle : Icons.radio_button_unchecked,
            ),
            title: Text(
              stages[i] == OrderStatuses.completed && !receiptConfirmed
                  ? 'Customer confirms receipt'
                  : OrderStatuses.label(
                      stages[i],
                      receiptConfirmed: receiptConfirmed,
                    ),
            ),
            subtitle: i == index ? const Text('Current status') : null,
          ),
      ],
    );
  }
}

class ReceiptConfirmation extends StatelessWidget {
  final bool busy, hasOpenIssue;
  final Future<void> Function() onConfirm;
  const ReceiptConfirmation({
    super.key,
    required this.busy,
    required this.hasOpenIssue,
    required this.onConfirm,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The rider has confirmed delivery. Please confirm only after receiving your bouquet.',
          ),
          if (hasOpenIssue)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Your delivery issue is awaiting store review. Receipt confirmation is paused.',
              ),
            ),
          FilledButton(
            onPressed: busy || hasOpenIssue
                ? null
                : () async {
                    if (await confirmAction(
                          context,
                          title: 'Confirm receipt?',
                          message:
                              'Confirm that you received this bouquet. This completes the order.',
                          action: 'Confirm received',
                        ) &&
                        context.mounted) {
                      await onConfirm();
                    }
                  },
            child: Text(busy ? 'Confirming…' : 'Confirm received'),
          ),
          const Text(
            'If the order is missing or damaged, use Report a problem below.',
          ),
        ],
      ),
    ),
  );
}
