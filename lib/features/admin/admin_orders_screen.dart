import 'package:flutter/material.dart';
import '../../core/constants/fulfillment_constants.dart';
import '../../core/services/admin_service.dart';
import '../../core/utils/malaysia_time.dart';
import 'admin_widgets.dart';
import 'admin_order_detail_screen.dart';
import 'admin_layout.dart';
import 'admin_navigation_scope.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({
    super.key,
    this.initialStatus,
    this.initialPayment,
    this.initialMode,
    this.initialDates,
    this.initialDateField = 'createdAt',
    this.ordersLoader,
  });
  final String? initialStatus, initialPayment;
  final String? initialMode;
  final DateTimeRange? initialDates;
  final String initialDateField;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  ordersLoader;
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late String _status = widget.initialStatus ?? '';
  late String _payment = widget.initialPayment ?? '';
  late String _mode = widget.initialMode ?? '';
  late String _dateField = widget.initialDateField;
  String _fulfillment = '', _searchValue = '';
  final _search = TextEditingController();
  final List<String?> _pages = [null];
  late DateTimeRange? _dates = widget.initialDates;
  int _revision = 0;
  void _change(VoidCallback action) => setState(() {
    action();
    _pages
      ..clear()
      ..add(null);
    _revision++;
  });
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _filter(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> changed,
  ) => SizedBox(
    width: 245,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('All')),
        ...values.map(
          (v) => DropdownMenuItem(
            value: v,
            child: Text(switch (v) {
              'preparation' => 'Awaiting / in preparation',
              'ready_now' => 'Ready to Send',
              'pre_order' => 'Pre-Order',
              'custom' => 'Custom Bouquet',
              'not_required' => 'Demo / not required',
              'needs_review' => 'Needs review',
              'manual' => 'Manual payment',
              'toyyibpay_sandbox' => 'ToyyibPay sandbox',
              'demo' => 'Demo',
              _ => v,
            }, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) => _change(() => changed(v ?? '')),
    ),
  );
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminSectionScope.contains(context)
        ? null
        : AppBar(title: const Text('Orders and payments')),
    body: Column(
      children: [
        if (AdminSectionScope.contains(context))
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: AdminHeading(
              title: 'Orders & payments',
              subtitle:
                  'Review orders, payment receipts and fulfilment queues.',
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .46,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: 'Search exact order ID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Search',
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () =>
                          _change(() => _searchValue = _search.text.trim()),
                    ),
                  ),
                  onSubmitted: (v) => _change(() => _searchValue = v.trim()),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _filter('Order status', _status, const [
                      'preparation',
                      OrderStatuses.awaitingPreparation,
                      OrderStatuses.legacyPending,
                      OrderStatuses.processing,
                      OrderStatuses.readyForDelivery,
                      OrderStatuses.outForDelivery,
                      OrderStatuses.awaitingConfirmation,
                      OrderStatuses.completed,
                      OrderStatuses.delivered,
                      OrderStatuses.cancelled,
                    ], (v) => _status = v),
                    _filter('Payment status', _payment, const [
                      'paid',
                      'pending',
                      'expired',
                      'not_required',
                      'needs_review',
                    ], (v) => _payment = v),
                    _filter(
                      'Fulfilment',
                      _fulfillment,
                      FulfillmentTypes.values,
                      (v) => _fulfillment = v,
                    ),
                    _filter('Payment mode', _mode, const [
                      'manual',
                      'toyyibpay_sandbox',
                      'demo',
                    ], (v) => _mode = v),
                    SizedBox(
                      width: 245,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey(_dateField),
                        initialValue: _dateField,
                        decoration: const InputDecoration(
                          labelText: 'Date filter applies to',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'createdAt',
                            child: Text('Order placed'),
                          ),
                          DropdownMenuItem(
                            value: 'paidAt',
                            child: Text('Payment received'),
                          ),
                        ],
                        onChanged: (v) => _change(() => _dateField = v!),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickDates,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _dates == null
                            ? 'Created date range'
                            : '${_dates!.start.day}/${_dates!.start.month} – ${_dates!.end.day}/${_dates!.end.month}',
                      ),
                    ),
                    TextButton(
                      onPressed: () => _change(() {
                        _status = '';
                        _payment = '';
                        _fulfillment = '';
                        _mode = '';
                        _dateField = 'createdAt';
                        _dates = null;
                        _searchValue = '';
                        _search.clear();
                      }),
                      child: const Text('Clear filters'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AdminLoad(
            key: ValueKey(_revision),
            load: () =>
                (widget.ordersLoader ??
                ((data) => AdminService().call('adminOrders', data)))({
                  'dateField': _dateField,
                  if (_mode.isNotEmpty) 'mode': _mode,
                  if (_status.isNotEmpty) 'status': _status,
                  if (_payment.isNotEmpty) 'payment': _payment,
                  if (_fulfillment.isNotEmpty) 'fulfillment': _fulfillment,
                  if (_searchValue.isNotEmpty) 'search': _searchValue,
                  if (_pages.last != null) 'after': _pages.last,
                  if (_dates != null)
                    'from': malaysiaDateBoundary(
                      _dates!.start,
                    ).millisecondsSinceEpoch,
                  if (_dates != null)
                    'to': malaysiaDateBoundary(
                      DateTime.utc(
                        _dates!.end.year,
                        _dates!.end.month,
                        _dates!.end.day + 1,
                      ),
                    ).millisecondsSinceEpoch,
                }),
            builder: (data, refresh) {
              final rows = (data['orders'] as List? ?? [])
                  .map((v) => Map<String, dynamic>.from(v as Map))
                  .toList();
              void details(String id) =>
                  openAdminPage(context, AdminOrderDetailScreen(orderId: id));
              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(
                            child: Text('No orders match these filters.'),
                          )
                        : LayoutBuilder(
                            builder: (context, c) {
                              String price(Map<String, dynamic> r) =>
                                  'RM ${((r['totalAmount'] as num?) ?? 0).toStringAsFixed(2)}';
                              String status(Map<String, dynamic> r) =>
                                  OrderStatuses.label(
                                    (r['orderStatus'] ?? '').toString(),
                                    receiptConfirmed:
                                        r['customerAcceptedAt'] != null,
                                  );
                              if (c.maxWidth >= 900) {
                                return SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Order ID')),
                                        DataColumn(label: Text('Recipient')),
                                        DataColumn(label: Text('Fulfilment')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Payment')),
                                        DataColumn(label: Text('Amount')),
                                      ],
                                      rows: rows
                                          .map(
                                            (r) => DataRow(
                                              onSelectChanged: (_) =>
                                                  details(r['id']),
                                              cells: [
                                                DataCell(Text(r['id'])),
                                                DataCell(
                                                  Text(
                                                    r['recipientName'] ?? '',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    FulfillmentTypes.customerLabel(
                                                      r['fulfillmentType'] ??
                                                          '',
                                                    ),
                                                  ),
                                                ),
                                                DataCell(Text(status(r))),
                                                DataCell(
                                                  Text(
                                                    '${r['paymentStatus'] ?? 'Unknown'}\n${r['orderMode'] ?? 'Legacy'}',
                                                  ),
                                                ),
                                                DataCell(Text(price(r))),
                                              ],
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: rows.length,
                                itemBuilder: (context, i) {
                                  final r = rows[i];
                                  return Card(
                                    child: ListTile(
                                      isThreeLine: true,
                                      title: Text(
                                        '${r['recipientName'] ?? 'Order'} · ${price(r)}',
                                      ),
                                      subtitle: Text(
                                        '${r['id']}\n${status(r)}\nPayment: ${r['paymentStatus'] ?? 'Unknown'} · ${r['orderMode'] ?? 'Legacy'}',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => details(r['id']),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Page ${_pages.length}'),
                        OutlinedButton(
                          onPressed: _pages.length > 1
                              ? () => setState(() {
                                  _pages.removeLast();
                                  _revision++;
                                })
                              : null,
                          child: const Text('Previous'),
                        ),
                        FilledButton(
                          onPressed: data['next'] != null
                              ? () => setState(() {
                                  _pages.add(data['next'] as String);
                                  _revision++;
                                })
                              : null,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
