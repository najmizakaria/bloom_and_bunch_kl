import '../../../core/widgets/map_access.dart';
import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import '../../../core/widgets/live_order_detail.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/services/order_service.dart';
import '../../support/order_support.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../widgets/rider_delivery_details.dart';
import '../../../models/order_model.dart';

class RiderOrderDetailScreen extends StatelessWidget {
  const RiderOrderDetailScreen({super.key, required this.order, this.watch});
  final OrderModel order;
  final OrderWatch? watch;
  @override
  Widget build(BuildContext context) => LiveOrderDetail(
    orderId: order.orderId,
    watch: watch,
    builder: (latest) => _RiderOrderDetailContent(order: latest),
  );
}

class _RiderOrderDetailContent extends StatefulWidget {
  final OrderModel order;

  const _RiderOrderDetailContent({required this.order});

  @override
  State<_RiderOrderDetailContent> createState() =>
      _RiderOrderDetailContentState();
}

class _RiderOrderDetailContentState extends State<_RiderOrderDetailContent> {
  bool _isLoading = false;

  LatLng? _deliveryLocation;
  bool _isLoadingMap = true;
  bool _approximate = false;
  int _mapRequest = 0;

  @override
  void initState() {
    super.initState();
    _fetchCoordinates();
  }

  @override
  void didUpdateWidget(covariant _RiderOrderDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.deliveryAddress != widget.order.deliveryAddress ||
        oldWidget.order.latitude != widget.order.latitude ||
        oldWidget.order.longitude != widget.order.longitude) {
      _fetchCoordinates();
    }
  }

  Future<void> _fetchCoordinates() async {
    final request = ++_mapRequest;
    setState(() {
      _isLoadingMap = true;
      _approximate = false;
    });
    try {
      if (widget.order.latitude != null && widget.order.longitude != null) {
        setState(() {
          _deliveryLocation = LatLng(
            widget.order.latitude!,
            widget.order.longitude!,
          );
          _isLoadingMap = false;
        });
        return;
      }
      if (kIsWeb) {
        // 🌐 WEB HANDLING: Avoids CORS network crashes on web browsers
        // Written address remains available when geocoding is unavailable.
        setState(() {
          _deliveryLocation = null;
          _isLoadingMap = false;
        });
      } else {
        // 🤖 MOBILE HANDLING: Uses native Android Geocoding API
        final geocoding = Geocoding();
        List<Location> locations = await geocoding.locationFromAddress(
          widget.order.deliveryAddress,
        );

        if (!mounted || request != _mapRequest) return;
        if (locations.isNotEmpty && mounted) {
          setState(() {
            _approximate = true;
            _deliveryLocation = LatLng(
              locations.first.latitude,
              locations.first.longitude,
            );
            _isLoadingMap = false;
          });
        } else if (mounted) {
          setState(() {
            _deliveryLocation = null;
            _isLoadingMap = false;
          });
        }
      }
    } catch (e) {
      if (mounted && request == _mapRequest) {
        setState(() {
          _deliveryLocation = null;
          _isLoadingMap = false;
        });
      }
    }
  }

  Future<void> _markAsDelivered() async {
    if (_isLoading) return;
    final collecting = widget.order.orderStatus == 'Rider assigned';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(collecting ? 'Confirm collection?' : 'Confirm delivered?'),
        content: Text(
          collecting
              ? 'Confirm that you have collected the packed order from the florist. The customer will see that delivery has started.'
              : 'Confirm the bouquet has been handed to the recipient or left according to their instructions. The order will wait for customer receipt confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              collecting ? 'Confirm collection' : 'Confirm delivered',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await OrderService().transition(
        widget.order.orderId,
        collecting ? 'collect' : 'deliver',
      );
      if (mounted && !collecting) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(OrderService.message(e))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collecting = widget.order.orderStatus == 'Rider assigned';
    final active = collecting || widget.order.orderStatus == 'Out for Delivery';
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('My delivery'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Report delivery problem',
            onPressed: () => reportIssue(context, widget.order.orderId),
            icon: const Icon(Icons.report_problem_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (collecting)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Rider assigned — collect the packed order from the florist, then confirm collection. Delivery has not started yet.',
                ),
              ),
            if (widget.order.hasOpenIssue)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'An open delivery issue pauses completion. Contact the store.',
                ),
              ),
            if (widget.order.orderStatus == 'Awaiting Customer Confirmation')
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Delivery recorded. Waiting for customer receipt confirmation.',
                ),
              ),
            RiderDeliveryDetails(order: widget.order),
            const SizedBox(height: 24),
            const Text('Delivery map', style: AppTypography.sectionTitle()),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              width: double.infinity,
              child: _isLoadingMap
                  ? const Center(child: CircularProgressIndicator())
                  : _deliveryLocation == null
                  ? Container(
                      color: Colors.grey.shade200,
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Map unavailable. Use the written delivery address.',
                                textAlign: TextAlign.center,
                              ),
                              if (!kIsWeb)
                                TextButton(
                                  onPressed: _fetchCoordinates,
                                  child: const Text('Retry map'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : MapAccess(
                      errorBuilder: (context, retry) => ColoredBox(
                        color: AppColors.secondarySurface,
                        child: Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.map_outlined),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'The map could not load. You can still open navigation to this delivery.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    children: [
                                      TextButton(
                                        onPressed: retry,
                                        child: const Text('Retry map'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            RiderNavigation.navigate(
                                              context,
                                              widget.order,
                                            ),
                                        icon: const Icon(
                                          Icons.navigation_outlined,
                                        ),
                                        label: const Text('Open Google Maps'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: GoogleMap(
                        key: ValueKey(
                          '${_deliveryLocation!.latitude},${_deliveryLocation!.longitude}',
                        ),
                        initialCameraPosition: CameraPosition(
                          target: _deliveryLocation!,
                          zoom: 15.0,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('delivery_dropoff'),
                            position: _deliveryLocation!,
                            infoWindow: InfoWindow(
                              title: widget.order.recipientName,
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueOrange,
                            ),
                          ),
                        },
                      ),
                    ),
            ),
            if (_approximate)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Approximate address marker. Confirm the exact entrance with the recipient.',
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => reportIssue(context, widget.order.orderId),
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report a delivery problem'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: active
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _isLoading || widget.order.hasOpenIssue
                    ? null
                    : _markAsDelivered,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        collecting ? 'Confirm collection' : 'Mark as Delivered',
                        style: const AppTypography.button(color: Colors.white),
                      ),
              ),
            )
          : null,
    );
  }
}
