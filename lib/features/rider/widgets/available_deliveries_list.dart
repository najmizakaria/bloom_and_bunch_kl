import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/delivery_service.dart';
import '../../../core/utils/malaysia_time.dart';
import '../../../models/delivery_job_model.dart';
import '../screens/rider_available_job_screen.dart';

class AvailableDeliveriesList extends StatefulWidget {
  const AvailableDeliveriesList({
    super.key,
    required this.active,
    required this.onMyDelivery,
    this.load,
  });
  final bool active;
  final VoidCallback onMyDelivery;
  final Future<AvailableDeliveryPage> Function(Map<String, dynamic>?)? load;
  @override
  State<AvailableDeliveriesList> createState() =>
      _AvailableDeliveriesListState();
}

class _AvailableDeliveriesListState extends State<AvailableDeliveriesList>
    with WidgetsBindingObserver {
  final List<Map<String, dynamic>?> _cursors = [null];
  AvailableDeliveryPage? _page;
  // Keep preparation records hidden during a client/backend rollout as well.
  List<DeliveryJobModel> get _readyDeliveries =>
      _page?.deliveries.where((job) => job.readyForPickup).toList() ?? [];
  String? _error;
  bool _loading = false, _foreground = true;
  Timer? _timer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.active &&
          _foreground &&
          !_loading &&
          ModalRoute.of(context)?.isCurrent == true) {
        _fetch();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AvailableDeliveriesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && widget.active) _refresh();
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    _cursors
      ..clear()
      ..add(null);
    await _fetch();
  }

  Future<void> _fetch() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await (widget.load ?? DeliveryService().available)(
        _cursors.last,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _page = page);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = DeliveryService.message(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              if (_page?.activeDeliveryId != null)
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text(
                          'Complete your current delivery and wait for customer receipt confirmation before accepting another.',
                        ),
                        TextButton(
                          onPressed: widget.onMyDelivery,
                          child: const Text('Open My Delivery'),
                        ),
                      ],
                    ),
                  ),
                ),
              const Text(
                'Only deliveries ready for pickup appear here. The first rider to accept gets the delivery.',
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : _refresh,
                  child: const Text('Retry'),
                ),
              ],
              if (!_loading &&
                  _error == null &&
                  _page != null &&
                  _readyDeliveries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _page?.nextCursor == null
                        ? 'No available deliveries are waiting.'
                        : 'No eligible deliveries on this page. Continue to the next page.',
                  ),
                ),
              for (final job in _readyDeliveries)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      job.readyForPickup
                          ? Icons.local_shipping_outlined
                          : Icons.hourglass_empty,
                    ),
                    title: Text(job.deliveryArea),
                    subtitle: Text(
                      '${job.readyForPickup ? 'Ready for pickup' : 'Waiting for preparation'}\n${job.deliveryTimeSlot}\nOrdered ${malaysiaTime(job.createdAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _loading || _error != null
                        ? null
                        : () async {
                            final route = MaterialPageRoute<String>(
                              builder: (_) => RiderAvailableJobScreen(
                                job: job,
                                hasActiveDelivery:
                                    _page?.activeDeliveryId != null,
                              ),
                            );
                            final accepted = await Navigator.push<String>(
                              context,
                              route,
                            );
                            // The push result resolves when pop starts. Finish
                            // removing the preview before changing its source tab.
                            await route.completed;
                            if (!mounted) return;
                            if (accepted != null) widget.onMyDelivery();
                            await _refresh();
                          },
                  ),
                ),
            ],
          ),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              TextButton(
                onPressed: _loading || _cursors.length == 1
                    ? null
                    : () {
                        _cursors.removeLast();
                        _fetch();
                      },
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: _loading ? null : _refresh,
                child: const Text('Refresh'),
              ),
              TextButton(
                onPressed:
                    _loading || _error != null || _page?.nextCursor == null
                    ? null
                    : () {
                        _cursors.add(_page!.nextCursor);
                        _fetch();
                      },
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
