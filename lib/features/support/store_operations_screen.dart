import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../core/services/order_service.dart';
import 'order_support.dart';

class StoreOperationsScreen extends StatefulWidget {
  const StoreOperationsScreen({super.key});
  @override
  State<StoreOperationsScreen> createState() => _StoreOperationsScreenState();
}
class _StoreOperationsScreenState extends State<StoreOperationsScreen> {
  String _view = 'Issues';
  int _limit = 30;
  final Set<String> _busy = {};
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _query();
  Stream<QuerySnapshot<Map<String, dynamic>>> _query() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('orders');
    q = switch (_view) {
      'Issues' => q.where('support.status', isEqualTo: 'open'),
      'Awaiting rider' => q.where('orderStatus', isEqualTo: 'Ready for Delivery'),
      'Payments' => q.where('paymentStatus', isEqualTo: 'pending'),
      _ => q.where('feedback.rating', isGreaterThanOrEqualTo: 1),
    };
    return q.limit(_limit).snapshots();
  }
  Future<void> _action(String id, String callable, Map<String, dynamic> data) async {
    setState(() => _busy.add(id));
    try {
      await FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable(callable).call({'orderId': id, ...data});
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(OrderService.message(e)))); }
    finally { if (mounted) setState(() => _busy.remove(id)); }
  }
  Future<void> _resolve(String id) async {
    final response = await showDialog<String>(context: context, builder: (_) => const _ResolutionDialog());
    if (response != null && mounted) await _action(id, 'resolveOrderIssue', {'response': response});
  }
  Future<void> _payment(String id) async {
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Confirm payment received?'), content: const Text('Only confirm after checking the actual payment. This records receipt; it does not charge the customer.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Back')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Payment received'))]));
    if (confirmed == true && mounted) await _action(id, 'confirmManualPayment', {});
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Store support')), body: Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: DropdownButtonFormField<String>(initialValue: _view, decoration: const InputDecoration(labelText: 'Work queue'), items: ['Issues', 'Awaiting rider', 'Payments', 'Feedback'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() { _view = v!; _limit = 30; _stream = _query(); }))),
    Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _stream, builder: (context, s) {
      if (s.hasError) return Center(child: OutlinedButton(onPressed: () => setState(() => _stream = _query()), child: const Text('Could not load queue. Retry')));
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final docs = s.data!.docs;
      if (docs.isEmpty) return const Center(child: Text('No orders in this queue.'));
      final rated = docs.where((d) => d.data()['feedback'] is Map && d.data()['orderMode'] != 'demo').toList();
      final satisfied = rated.where((d) => (d.data()['feedback']['rating'] as num) >= 4).length;
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (_view == 'Feedback') Text('Loaded non-demo responses: ${rated.length}. Satisfied: $satisfied/${rated.length}. This is a response sample, not all customers.'),
        for (final doc in docs) Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Order ${doc.id.substring(0, doc.id.length < 8 ? doc.id.length : 8)}', style: Theme.of(context).textTheme.titleMedium),
          Text('${doc.data()['orderStatus']} · RM ${((doc.data()['totalAmount'] as num?) ?? 0).toStringAsFixed(2)}'),
          if (doc.data()['orderMode'] == 'demo') const Text('Demo order'),
          if (_view == 'Issues') ...[
            Text(issueReasons[doc.data()['support']['reason']] ?? 'Order issue'), Text(doc.data()['support']['comment']?.toString() ?? ''),
            FilledButton(onPressed: _busy.contains(doc.id) ? null : () => _resolve(doc.id), child: const Text('Respond and resolve')),
          ],
          if (_view == 'Awaiting rider') ...[
            Text('Estimated dispatch: ${doc.data()['estimatedDispatchDate'] ?? 'Contact customer to confirm'}'),
            Text('Recipient: ${doc.data()['recipientName'] ?? ''} · ${doc.data()['recipientPhone'] ?? ''}'),
            const Text('Review rider availability and contact the customer if delayed.'),
          ],
          if (_view == 'Payments') FilledButton(onPressed: _busy.contains(doc.id) ? null : () => _payment(doc.id), child: const Text('Confirm payment received')),
          if (_view == 'Feedback') Text('${doc.data()['feedback']['rating']}/5 · ${doc.data()['feedback']['comment'] ?? ''}'),
        ]))),
        if (docs.length >= _limit) OutlinedButton(onPressed: () => setState(() { _limit += 30; _stream = _query(); }), child: const Text('Load more')),
      ]);
    })),
  ]));
}
class _ResolutionDialog extends StatefulWidget {
  const _ResolutionDialog();
  @override
  State<_ResolutionDialog> createState() => _ResolutionDialogState();
}
class _ResolutionDialogState extends State<_ResolutionDialog> {
  final _text = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() { _text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Response to customer'), content: Form(key: _form, child: TextFormField(controller: _text, maxLength: 500, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Resolution'), validator: (v) => v == null || v.trim().isEmpty ? 'Describe how the issue was resolved.' : null)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')), FilledButton(onPressed: () { if (_form.currentState!.validate()) Navigator.pop(context, _text.text.trim()); }, child: const Text('Resolve issue'))]);
}
