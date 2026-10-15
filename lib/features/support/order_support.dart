import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/order_service.dart';
import '../../core/services/app_monitoring.dart';

const issueReasons = {
  'late_delivery': 'Delivery is late',
  'wrong_address': 'Address or entrance problem',
  'recipient_unavailable': 'Recipient unavailable',
  'damaged_bouquet': 'Bouquet quality problem',
  'cancellation_request': 'Request cancellation',
  'not_received': 'I have not received my order',
  'other': 'Something else',
};
Future<void> contactStore(BuildContext context) async {
  try {
    if (await launchUrl(Uri(scheme: 'tel', path: '+60148376919'))) return;
  } catch (_) {
    /* Show the number if no phone application is available. */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call the store at +60 14-837 6919.')),
    );
  }
}

Future<void> reportIssue(BuildContext context, String orderId) async {
  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (_) => const _IssueDialog(),
  );
  if (result == null || !context.mounted) return;
  try {
    await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('reportOrderIssue').call({'orderId': orderId, ...result});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your issue is with the store. Check this order for a response.',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(OrderService.message(e))));
    }
  }
}

class OrderSupportPanel extends StatefulWidget {
  const OrderSupportPanel({
    super.key,
    required this.orderId,
    required this.order,
  });
  final String orderId;
  final Map<String, dynamic> order;
  @override
  State<OrderSupportPanel> createState() => _OrderSupportPanelState();
}

class _OrderSupportPanelState extends State<OrderSupportPanel> {
  bool _busy = false;
  int _rating = 5;
  final _comment = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('submitOrderFeedback').call({
        'orderId': widget.orderId,
        'rating': _rating,
        'comment': _comment.text.trim(),
      });
      AppMonitoring.event('feedback_submitted');
    } catch (e) {
      if (mounted) setState(() => _error = OrderService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final support = widget.order['support'] as Map?;
    final feedback = widget.order['feedback'] as Map?;
    final delivered = [
      'Delivered',
      'Completed',
    ].contains(widget.order['orderStatus']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Help with this order',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => contactStore(context),
              icon: const Icon(Icons.phone_outlined),
              label: const Text('Contact store'),
            ),
            OutlinedButton(
              onPressed: support?['status'] == 'open'
                  ? null
                  : () => reportIssue(context, widget.orderId),
              child: const Text('Report a problem'),
            ),
          ],
        ),
        if (support != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    support['status'] == 'open'
                        ? 'Your issue is awaiting store review'
                        : 'Store response',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(issueReasons[support['reason']] ?? 'Order issue'),
                  if ((support['comment'] ?? '').toString().isNotEmpty)
                    Text(support['comment'].toString()),
                  if (support['response'] != null)
                    Text(support['response'].toString()),
                ],
              ),
            ),
          ),
        if (delivered) ...[
          const SizedBox(height: 24),
          Text(
            'How was your experience?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (feedback != null)
            Text('Thank you. Your rating: ${feedback['rating']}/5.')
          else ...[
            const Text(
              'Rate the overall ordering and delivery experience. Feedback is optional.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _rating,
              decoration: const InputDecoration(labelText: 'Satisfaction'),
              items: const [
                DropdownMenuItem(
                  value: 1,
                  child: Text('1 · Very dissatisfied'),
                ),
                DropdownMenuItem(value: 2, child: Text('2 · Dissatisfied')),
                DropdownMenuItem(value: 3, child: Text('3 · Neutral')),
                DropdownMenuItem(value: 4, child: Text('4 · Satisfied')),
                DropdownMenuItem(value: 5, child: Text('5 · Very satisfied')),
              ],
              onChanged: _busy ? null : (v) => setState(() => _rating = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              enabled: !_busy,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What could we improve? (optional)',
              ),
            ),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Saving…' : 'Send feedback'),
            ),
          ],
        ],
      ],
    );
  }
}

class _IssueDialog extends StatefulWidget {
  const _IssueDialog();
  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  final _text = TextEditingController();
  String _reason = issueReasons.keys.first;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Report an order problem'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Problem'),
            items: issueReasons.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _reason = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              helperText: 'Do not include payment details or passwords.',
            ),
          ),
          const Text(
            'A cancellation request needs store review. Reporting a problem does not cancel the order.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, {
          'reason': _reason,
          'comment': _text.text.trim(),
        }),
        child: const Text('Send to store'),
      ),
    ],
  );
}
