import 'dart:math';
import '../../core/widgets/load_more_on_scroll.dart';
import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../core/services/delivery_service.dart';
import '../../core/services/order_service.dart';

class OrderRiderAssignment extends StatelessWidget {
  const OrderRiderAssignment({
    super.key,
    required this.order,
    this.load,
    this.submit,
  });
  final OrderModel order;
  final Future<Map<String, dynamic>> Function(String? cursor)? load;
  final Future<void> Function(Map<String, dynamic> request)? submit;

  Future<void> _open(BuildContext context, {bool unassign = false}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AssignmentDialog(
        order: order,
        unassign: unassign,
        load:
            load ??
            (cursor) =>
                DeliveryService().assignableRiders(order.orderId, cursor),
        submit:
            submit ??
            (request) => OrderService().transition(
              order.orderId,
              unassign ? 'unassign' : 'assign',
              details: request,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!['Ready for Delivery', 'Rider assigned'].contains(order.orderStatus)) {
      return const SizedBox.shrink();
    }
    final assigned = order.orderStatus == 'Rider assigned';
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
                      ? order.earlyDispatchDate != null
                            ? 'Early delivery arranged for ${order.earlyDispatchDate}. Waiting for the rider to confirm collection.'
                            : 'Waiting for the rider to confirm collection.'
                      : order.isFutureDelivery
                      ? 'Scheduled for ${order.scheduledDeliveryDate}. You can assign early if the customer requests delivery today.'
                      : 'Available to riders now — awaiting a rider.'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: blocked == null ? () => _open(context) : null,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(assigned ? 'Reassign rider' : 'Assign rider'),
                ),
                if (assigned)
                  OutlinedButton(
                    onPressed: () => _open(context, unassign: true),
                    child: const Text('Unassign rider'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({
    required this.order,
    required this.unassign,
    required this.load,
    required this.submit,
  });
  final OrderModel order;
  final bool unassign;
  final Future<Map<String, dynamic>> Function(String?) load;
  final Future<void> Function(Map<String, dynamic>) submit;
  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final _reason = TextEditingController();
  final _requestId =
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}';
  final _form = GlobalKey<FormState>();
  List<Map<String, dynamic>> _riders = [];
  String? _cursor, _selected, _selectedName, _error;
  bool _loading = false, _saving = false;
  bool _earlyConfirmed = false;
  bool get _requiresEarlyConfirmation =>
      !widget.unassign && widget.order.isFutureDelivery;
  @override
  void initState() {
    super.initState();
    if (!widget.unassign) _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var cursor = next ? _cursor : null;
      final visited = <String?>{};
      late Map<String, dynamic> result;
      do {
        if (!visited.add(cursor)) {
          throw StateError('The rider list could not continue. Please reload.');
        }
        result = await widget.load(cursor);
        cursor = result['nextCursor'] as String?;
      } while ((result['riders'] as List).isEmpty && cursor != null);
      if (!mounted) return;
      setState(() {
        final riders = (result['riders'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _riders = next ? [..._riders, ...riders] : riders;
        _cursor = cursor;
      });
    } catch (error) {
      if (mounted) setState(() => _error = OrderService.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving || _loading) return;
    if (_requiresEarlyConfirmation && !_earlyConfirmed) return;
    if (!widget.unassign && _selected == null) {
      setState(() => _error = 'Choose a rider first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.submit({
        'expectedRiderId': widget.order.riderId,
        'expectedAssignmentRevision': widget.order.assignmentRevision,
        'requestId': _requestId,
        if (!widget.unassign) 'riderId': _selected,
        if (_requiresEarlyConfirmation) 'earlyDispatchConfirmed': true,
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
    title: Text(
      widget.unassign
          ? 'Unassign rider?'
          : widget.order.riderId == null
          ? 'Assign rider'
          : 'Reassign rider',
    ),
    content: SizedBox(
      width: 440,
      child: LoadMoreOnScroll(
        hasMore: _cursor != null && _error == null,
        busy: _loading || _saving,
        onLoad: () => _load(next: true),
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.unassign)
                  const Text(
                    'The order will return to the rider queue if eligible. Collection must not have started.',
                  )
                else ...[
                  if (_requiresEarlyConfirmation) ...[
                    Text(
                      'This order is scheduled for ${widget.order.scheduledDeliveryDate}. Assign a rider for delivery today (Malaysia time)?',
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'The customer requested delivery today.',
                      ),
                      value: _earlyConfirmed,
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _earlyConfirmed = value == true),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Approved riders without an active delivery. This does not confirm they are online; contact the rider before assigning.',
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                  if (!_loading && _riders.isEmpty)
                    const Text(
                      'No eligible riders are available. The order stays ready to ship.',
                    ),
                  for (final rider in _riders)
                    ListTile(
                      title: Text(rider['name'] as String),
                      leading: Icon(
                        _selected == rider['id']
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      selected: _selected == rider['id'],
                      enabled: !_saving && !_loading,
                      onTap: () => setState(() {
                        _selected = rider['id'] as String;
                        _selectedName = rider['name'] as String;
                      }),
                    ),
                  if (_selectedName != null) Text('Selected: $_selectedName'),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _loading || _saving ? null : _load,
                        child: const Text('Refresh riders'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  enabled: !_saving,
                  maxLength: 240,
                  decoration: InputDecoration(
                    labelText: widget.order.riderId == null
                        ? 'Assignment note (optional)'
                        : 'Reason for change',
                  ),
                  validator: (value) =>
                      widget.order.riderId != null &&
                          (value?.trim().isEmpty ?? true)
                      ? 'Enter a reason.'
                      : null,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            _saving ||
                _loading ||
                (_requiresEarlyConfirmation && !_earlyConfirmed)
            ? null
            : _save,
        child: Text(
          _saving
              ? 'Saving…'
              : widget.unassign
              ? 'Unassign rider'
              : 'Confirm assignment',
        ),
      ),
    ],
  );
}
