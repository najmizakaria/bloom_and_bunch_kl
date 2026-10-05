import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../core/constants/fulfillment_constants.dart';
import '../../core/services/order_service.dart';
import '../../core/utils/malaysia_time.dart';
import '../../core/widgets/firestore_page.dart';
import '../customer/screens/order_tracking_screen.dart';

class RiderHistoryScreen extends StatefulWidget {
  const RiderHistoryScreen({super.key, this.queryOverride, this.ridersLoader});
  final Query<Map<String, dynamic>>? queryOverride;
  final Future<Map<String, dynamic>> Function(String? after)? ridersLoader;
  @override
  State<RiderHistoryScreen> createState() => _RiderHistoryScreenState();
}

class _RiderHistoryScreenState extends State<RiderHistoryScreen> {
  final Map<String, String> _riders = {};
  String? _rider, _next;
  String _status = 'All';
  bool _loading = false, _openOnly = false;
  String? _error;
  DateTimeRange? _dates;
  int _revision = 0;
  static const _statuses = [
    'Out for Delivery',
    'Awaiting Customer Confirmation',
    'Completed',
    'Delivered',
  ];
  @override
  void initState() {
    super.initState();
    _loadRiders();
  }

  Future<void> _loadRiders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = widget.ridersLoader != null
          ? await widget.ridersLoader!(_next)
          : Map<String, dynamic>.from(
              (await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
                      .httpsCallable('listRiders')
                      .call({if (_next != null) 'after': _next}))
                  .data,
            );
      if (!mounted) return;
      setState(() {
        for (final r in data['riders'] as List) {
          _riders[r['uid'] as String] = r['name'] as String;
        }
        _next = data['next'] as String?;
      });
    } catch (e) {
      if (mounted) setState(() => _error = OrderService.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Query<Map<String, dynamic>> _query() {
    if (widget.queryOverride != null) return widget.queryOverride!;
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('orders')
        .where(
          'orderStatus',
          whereIn: _status == 'All' ? _statuses : [_status],
        );
    if (_rider != null) query = query.where('riderId', isEqualTo: _rider);
    if (_openOnly) query = query.where('support.status', isEqualTo: 'open');
    if (_dates != null) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              malaysiaDateBoundary(_dates!.start),
            ),
          )
          .where(
            'createdAt',
            isLessThan: Timestamp.fromDate(
              malaysiaDateBoundary(_dates!.end.add(const Duration(days: 1))),
            ),
          );
    }
    return query.orderBy('createdAt', descending: true);
  }

  void _change(VoidCallback action) => setState(() {
    action();
    _revision++;
  });
  Future<void> _pickDates() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _dates,
    );
    if (dates != null && mounted) _change(() => _dates = dates);
  }

  Widget _time(Map<String, dynamic> order, String field, String label) => Text(
    '$label: ${order[field] is Timestamp ? malaysiaTime((order[field] as Timestamp).toDate()) : 'Not recorded'}',
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const PageBackButton(),
      centerTitle: false,
      title: const Text('Rider history'),
    ),
    body: Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    itemHeight: null,
                    initialValue: _rider ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Rider'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All riders'),
                      ),
                      for (final r in _riders.entries)
                        DropdownMenuItem(
                          value: r.key,
                          child: Text(
                            '${r.value} · ${r.key}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        _change(() => _rider = v == '' ? null : v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    itemHeight: null,
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final s in ['All', ..._statuses])
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (s) => _change(() => _status = s!),
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _pickDates,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _dates == null
                              ? 'Order creation dates (MYT)'
                              : '${_dates!.start.day}/${_dates!.start.month} – ${_dates!.end.day}/${_dates!.end.month} (MYT)',
                        ),
                      ),
                      if (_dates != null)
                        TextButton(
                          onPressed: () => _change(() => _dates = null),
                          child: const Text('Clear dates'),
                        ),
                      FilterChip(
                        label: const Text('Open issues'),
                        selected: _openOnly,
                        onSelected: (v) => _change(() => _openOnly = v),
                      ),
                      if (_loading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (_next != null)
                        TextButton(
                          onPressed: _loading ? null : _loadRiders,
                          child: const Text('Load more rider names'),
                        ),
                    ],
                  ),
                  if (_error != null)
                    TextButton(
                      onPressed: _loadRiders,
                      child: Text('$_error Retry rider names'),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: FirestorePage(
            key: ValueKey(_revision),
            query: _query(),
            emptyMessage: 'No deliveries match these filters.',
            builder: (context, docs) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final doc in docs)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order ${doc.id}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Rider: ${doc.data()['riderName'] ?? _riders[doc.data()['riderId']] ?? 'Name not recorded'} · ${doc.data()['riderId'] ?? 'Unassigned'}',
                          ),
                          Text(
                            OrderStatuses.label(
                              doc.data()['orderStatus'] as String,
                              receiptConfirmed:
                                  doc.data()['customerAcceptedAt'] is Timestamp,
                            ),
                          ),
                          _time(doc.data(), 'createdAt', 'Order created'),
                          _time(doc.data(), 'acceptedAt', 'Rider accepted'),
                          _time(doc.data(), 'deliveredAt', 'Rider delivered'),
                          _time(
                            doc.data(),
                            'customerAcceptedAt',
                            'Customer confirmed receipt',
                          ),
                          if (doc.data()['support'] is Map)
                            Text('Issue: ${doc.data()['support']['status']}'),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    OrderTrackingScreen(orderId: doc.id),
                              ),
                            ),
                            child: const Text(
                              'View order and recorded activity',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
