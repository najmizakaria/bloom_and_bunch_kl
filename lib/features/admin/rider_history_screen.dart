import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../core/constants/fulfillment_constants.dart';
import '../../core/services/admin_service.dart';
import '../../core/utils/malaysia_time.dart';
import '../../core/widgets/firestore_page.dart';
import 'admin_order_detail_screen.dart';
import 'admin_layout.dart';
import 'admin_widgets.dart';
import '../../core/theme/app_colors.dart';

class RiderHistoryScreen extends StatefulWidget {
  const RiderHistoryScreen({
    super.key,
    this.queryOverride,
    this.ridersLoader,
    this.embedded = false,
  });
  final bool embedded;
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
      if (mounted) setState(() => _error = AdminService.message(e));
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

  Widget _filters() => LayoutBuilder(
    builder: (context, box) {
      final narrow =
          box.maxWidth < 760 || MediaQuery.textScalerOf(context).scale(1) > 1.4;
      final fieldWidth = narrow ? box.maxWidth : 260.0;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: fieldWidth,
            child: DropdownButtonFormField<String>(
              itemHeight: null,
              initialValue: _rider ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Rider'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All riders')),
                for (final r in _riders.entries)
                  DropdownMenuItem(
                    value: r.key,
                    child: Text(r.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => _change(() => _rider = v == '' ? null : v),
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: DropdownButtonFormField<String>(
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
          ),
          OutlinedButton.icon(
            onPressed: _pickDates,
            icon: const Icon(Icons.date_range),
            label: Text(
              _dates == null
                  ? 'Order dates (MYT)'
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
          if (_error != null)
            TextButton(
              onPressed: _loadRiders,
              child: Text('$_error Retry rider names'),
            ),
        ],
      );
    },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.softBlushStart,
    appBar: widget.embedded
        ? null
        : AppBar(
            leading: const PageBackButton(),
            centerTitle: false,
            title: const Text('Rider history'),
          ),
    body: AdminPage(
      child: FirestorePage(
        key: ValueKey(_revision),
        query: _query(),
        pageBuilder: (context, docs, pagination) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const AdminHeading(
              title: 'Delivery history',
              subtitle:
                  'Review delivery progress, receipt confirmation and recorded activity.',
            ),
            const SizedBox(height: 24),
            _filters(),
            const SizedBox(height: 24),
            AdminDeliveryRecords(
              records: docs
                  .map((doc) => {...doc.data(), 'id': doc.id})
                  .toList(),
              riderNames: _riders,
              onOpen: (id) =>
                  openAdminPage(context, AdminOrderDetailScreen(orderId: id)),
            ),
            pagination,
          ],
        ),
      ),
    ),
  );
}

/// Compact summaries; the order detail retains the full recorded timeline.
class AdminDeliveryRecords extends StatelessWidget {
  const AdminDeliveryRecords({
    super.key,
    required this.records,
    required this.onOpen,
    this.riderNames = const {},
  });
  final List<Map<String, dynamic>> records;
  final Map<String, String> riderNames;
  final ValueChanged<String> onOpen;
  String _time(Map<String, dynamic> order, String field) =>
      order[field] is Timestamp
      ? malaysiaTime((order[field] as Timestamp).toDate())
      : 'Not recorded';
  String _name(Map<String, dynamic> order) =>
      '${order['riderName'] ?? riderNames[order['riderId']] ?? 'Name not recorded'}';
  Widget _status(Map<String, dynamic> order) => AdminBadge(
    order['orderStatus'] == 'Awaiting Customer Confirmation'
        ? 'Awaiting customer confirmation'
        : OrderStatuses.label(
            order['orderStatus'] as String,
            receiptConfirmed: order['customerAcceptedAt'] is Timestamp,
          ),
    color: order['customerAcceptedAt'] is Timestamp
        ? AppColors.statusReady
        : AppColors.primary,
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (records.isEmpty) {
        return const AdminEmpty(
          'No deliveries match these filters.',
          icon: Icons.delivery_dining,
        );
      }
      if (adminUsesTable(context, box.maxWidth)) {
        return AdminTable(
          columns: const [
            DataColumn(label: Text('Order')),
            DataColumn(label: Text('Rider')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Delivered (MYT)')),
            DataColumn(label: Text('Receipt confirmed (MYT)')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final order in records)
              DataRow(
                cells: [
                  DataCell(
                    SizedBox(width: 156, child: AdminIdentifier(order['id'])),
                  ),
                  DataCell(
                    SizedBox(
                      width: 130,
                      child: Text(
                        _name(order),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(SizedBox(width: 220, child: _status(order))),
                  DataCell(
                    SizedBox(
                      width: 170,
                      child: Text(_time(order, 'deliveredAt')),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 170,
                      child: Text(_time(order, 'customerAcceptedAt')),
                    ),
                  ),
                  DataCell(
                    TextButton(
                      onPressed: () => onOpen(order['id']),
                      child: const Text('View'),
                    ),
                  ),
                ],
              ),
          ],
        );
      }
      return Column(
        children: [
          for (final order in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminIdentifier(order['id']),
                      const SizedBox(height: 8),
                      Text(
                        _name(order),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _status(order),
                      const SizedBox(height: 12),
                      Text('Delivered: ${_time(order, 'deliveredAt')}'),
                      const SizedBox(height: 6),
                      Text(
                        'Receipt confirmed: ${_time(order, 'customerAcceptedAt')}',
                      ),
                      if (order['support'] is Map &&
                          order['support']['status'] == 'open') ...[
                        const SizedBox(height: 8),
                        const AdminBadge(
                          'Open support issue',
                          color: AppColors.statusLowStock,
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => onOpen(order['id']),
                        child: const Text('View order and timeline'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
