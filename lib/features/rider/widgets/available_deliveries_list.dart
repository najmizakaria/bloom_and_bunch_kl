import 'dart:async';
import '../../../core/widgets/load_more_on_scroll.dart';
import 'package:flutter/material.dart';
import '../../../core/services/delivery_service.dart';
import '../../../core/utils/malaysia_time.dart';
import '../../../models/delivery_job_model.dart';
import '../screens/rider_available_job_screen.dart';
import 'delivery_job_card.dart';

class AvailableDeliveriesList extends StatefulWidget {
  const AvailableDeliveriesList({
    super.key,
    required this.active,
    required this.onMyDelivery,
    this.load,
    this.changes,
  });
  final bool active;
  final VoidCallback onMyDelivery;
  final Future<AvailableDeliveryPage> Function(Map<String, dynamic>?)? load;
  final Stream<void>? changes;
  @override
  State<AvailableDeliveriesList> createState() =>
      _AvailableDeliveriesListState();
}

class _AvailableDeliveriesListState extends State<AvailableDeliveriesList>
    with WidgetsBindingObserver {
  AvailableDeliveryPage? _page;
  // Keep preparation records hidden during a client/backend rollout as well.
  List<DeliveryJobModel> get _readyDeliveries =>
      _page?.deliveries.where((job) => job.readyForPickup).toList() ?? [];
  String? _error;
  bool _loading = false, _foreground = true;
  Timer? _timer;
  Timer? _liveRefresh;
  StreamSubscription<void>? _changes;
  bool _refreshPending = false;
  int _generation = 0;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _listen();
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
    if (oldWidget.changes != widget.changes) _listen();
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
    _liveRefresh?.cancel();
    _changes?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _listen() {
    _changes?.cancel();
    _changes = widget.changes?.listen(
      (_) {
        if (!widget.active || !_foreground) return;
        if (_loading) {
          _refreshPending = true;
          return;
        }
        _scheduleRefresh();
      },
      onError: (Object error) {
        // Keep manual refresh and the polling fallback when live updates disconnect.
      },
    );
  }

  void _scheduleRefresh() {
    _liveRefresh?.cancel();
    _liveRefresh = Timer(const Duration(milliseconds: 200), () {
      if (mounted && widget.active && _foreground) _refresh();
    });
  }

  Future<void> _refresh() async {
    await _fetch();
  }

  Future<void> _fetch({bool append = false}) async {
    if (append && (_loading || _page?.nextCursor == null)) return;
    final generation = ++_generation;
    final target = _page?.deliveries.length ?? 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var cursor = append ? _page?.nextCursor : null;
      final visited = <String>{};
      final fetched = <DeliveryJobModel>[];
      late AvailableDeliveryPage page;
      do {
        if (!visited.add(cursor.toString())) {
          throw StateError(
            'The delivery list could not continue. Please reload.',
          );
        }
        page = await (widget.load ?? DeliveryService().available)(cursor);
        fetched.addAll(page.deliveries);
        cursor = page.nextCursor;
      } while (cursor != null &&
          (fetched.isEmpty || (!append && fetched.length < target)));
      if (!mounted || generation != _generation) return;
      final deliveries = <String, DeliveryJobModel>{
        if (append)
          for (final job in _page?.deliveries ?? <DeliveryJobModel>[])
            job.orderId: job,
        for (final job in fetched) job.orderId: job,
      };
      setState(() {
        _page = AvailableDeliveryPage(
          deliveries: deliveries.values.toList(),
          nextCursor: cursor,
          activeDeliveryId: page.activeDeliveryId,
          contactReady: page.contactReady,
        );
        _lastUpdated = DateTime.now();
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = DeliveryService.message(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        if (_refreshPending) {
          _refreshPending = false;
          _scheduleRefresh();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => LoadMoreOnScroll(
    hasMore: _page?.nextCursor != null && _error == null,
    busy: _loading,
    onLoad: () => _fetch(append: true),
    child: Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                if (_page?.contactReady == false)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Your delivery contact needs administrator review. Ask the store to approve your name and Malaysian phone number before accepting a delivery.',
                      ),
                    ),
                  ),
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
                  'Choose a delivery to see pickup and destination details before accepting.',
                ),
                if (_lastUpdated != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Text(
                      'Updated ${malaysiaTime(_lastUpdated!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
                    child: Text('No available deliveries are waiting.'),
                  ),
                for (final job in _readyDeliveries)
                  DeliveryJobCard(
                    job: job,
                    onView: _loading || _error != null
                        ? null
                        : () async {
                            final route = MaterialPageRoute<String>(
                              builder: (_) => RiderAvailableJobScreen(
                                job: job,
                                contactReady: _page?.contactReady != false,
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
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Center(
            child: IconButton(
              tooltip: 'Reload',
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
      ],
    ),
  );
}
