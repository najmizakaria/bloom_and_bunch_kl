import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../core/services/order_service.dart';

class OrderRiderAssignment extends StatefulWidget {
  const OrderRiderAssignment({super.key, required this.order, this.submit});
  final OrderModel order;
  final Future<void> Function(Map<String, dynamic>)? submit;

  @override
  State<OrderRiderAssignment> createState() => _OrderRiderAssignmentState();
}

class _OrderRiderAssignmentState extends State<OrderRiderAssignment> {
  bool _releasing = false, _released = false;
  String? _error;

  @override
  void didUpdateWidget(covariant OrderRiderAssignment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.orderId != widget.order.orderId ||
        oldWidget.order.assignmentRevision != widget.order.assignmentRevision ||
        oldWidget.order.orderStatus != widget.order.orderStatus) {
      _released = false;
      _error = null;
    }
  }

  Future<void> _submit(Map<String, dynamic> request) =>
      widget.submit?.call(request) ??
      OrderService().transition(
        widget.order.orderId,
        request['action'] as String,
        details: request,
      );

  Future<void> _release() async {
    if (_releasing || _released || widget.order.deliveryReleasedAt != null) {
      return;
    }
    setState(() {
      _releasing = true;
      _error = null;
    });
    try {
      await _submit({
        'action': 'release',
        'expectedAssignmentRevision': widget.order.assignmentRevision,
      });
      if (mounted) setState(() => _released = true);
    } catch (error) {
      if (mounted) setState(() => _error = OrderService.message(error));
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    if (!['Ready for Delivery', 'Rider assigned'].contains(order.orderStatus)) {
      return const SizedBox.shrink();
    }
    final assigned = order.orderStatus == 'Rider assigned';
    final released = _released || order.deliveryReleasedAt != null;
    final blocked = order.handoffBlockReason;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assigned
                  ? 'Rider assigned: ${order.riderName.isEmpty ? 'Name unavailable' : order.riderName}'
                  : 'Ready to ship',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              blocked ??
                  (assigned
                      ? 'Waiting for the rider to confirm collection.'
                      : released || !order.isFutureDelivery
                      ? 'Available to riders — waiting for acceptance.'
                      : 'Scheduled for ${order.scheduledDeliveryDate}. Assign rider releases this order for delivery today.'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            if (assigned)
              OutlinedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      _UnassignDialog(order: order, submit: _submit),
                ),
                child: const Text('Unassign rider'),
              )
            else
              FilledButton.icon(
                onPressed: blocked != null || _releasing || released
                    ? null
                    : _release,
                icon: _releasing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delivery_dining),
                label: Text(
                  _releasing
                      ? 'Releasing…'
                      : released
                      ? 'Available to riders'
                      : 'Assign rider',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnassignDialog extends StatefulWidget {
  const _UnassignDialog({required this.order, required this.submit});
  final OrderModel order;
  final Future<void> Function(Map<String, dynamic>) submit;

  @override
  State<_UnassignDialog> createState() => _UnassignDialogState();
}

class _UnassignDialogState extends State<_UnassignDialog> {
  final _reason = TextEditingController();
  final _requestId =
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}';
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.submit({
        'action': 'unassign',
        'expectedRiderId': widget.order.riderId,
        'expectedAssignmentRevision': widget.order.assignmentRevision,
        'requestId': _requestId,
        'reason': _reason.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = OrderService.message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Unassign rider?'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The order will return to the rider queue if eligible. Collection must not have started.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              enabled: !_saving,
              maxLength: 240,
              decoration: const InputDecoration(labelText: 'Reason for change'),
              validator: (value) =>
                  value?.trim().isNotEmpty == true ? null : 'Enter a reason.',
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Unassign rider'),
      ),
    ],
  );
}
